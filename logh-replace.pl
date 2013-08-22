#!/usr/bin/perl

# Программа выполняет замену слов в SRT- и ASS-субтитрах, расположенных в каталоге $src_dir.
# Таблица подстановок хранится в файлах subst-srt.txt и subst-ass.txt соответственно.
# Каждая строчка этого файла содержит два слова - что найти и на что заменить.
# "Что найти" может содержать пробелы и быть регулярным выражением, можно использовать опережающие проверки.
# "На что заменить" должно отделяться двумя или более символами пробела или табуляции.
# Результат подстановок помещается в каталог $out_dir.

use utf8;
use open ':utf8';
$src_dir = 'from';
$out_dir = 'replaced';

sub key_length {
	my ($s) = @_;
	$s =~ s/\(\?.+?\)//g;
	return length($s);
}


for $ext ('srt','ass')
{
	# Загрузить таблицу подстановок
	%subst = ();
	open SUBST, "subst-$ext.txt";
	while (<SUBST>) {
		next if m/^#/;
		chomp;
		my ($from, $to) = split /\s{2,}/;
		$subst{$from} = $to if ($from && $to);
	}
	close SUBST;

	# Упорядочить строки для поиска по убыванию их длины
	@sorted_keys = sort { key_length($b) <=> key_length($a) } keys %subst;
	
	# Делаем замены в каждом файле
	for $in_filename (glob $src_dir.'/*.'.$ext) {
		$count = 0;
		($out_filename = $in_filename) =~ s/$src_dir/$out_dir/;
		open IN, $in_filename;
		open OUT, '>', $out_filename;
		while ($line = <IN>) {
			for $from (@sorted_keys) {
				$count += ($line =~ s/$from/$subst{$from}/g);
				$count += ($line =~ s/(,,|\s|\\N)-(\s|\\N|$)/\1–\2/g);
			}
			print OUT $line;
		}
		close OUT;
		close IN;
		system "diff -u \"$in_filename\" \"$out_filename\" >\"$out_filename.diff\"";
		print "\"$in_filename\": $count replace(s)\n";
	}
}
