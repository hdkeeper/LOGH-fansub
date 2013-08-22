#!/usr/bin/perl

# Программа пытается объединить два набора ASS-субтитров, расположенных в каталогах $time_dir и $text_dir.
# Из субтитров из каталога $time_dir берутся метаданные, стили, временнЫе метки и прочее.
# Из субтитров из каталога $text_dir берутся только тексты событий.
# В процессе слияния отслеживается синхронность событий в обоих файлах, используя нечеткое сравнение строк по Левенштейну.
# В случае сбоя синхронизации программа пытается восстановить её, просматривая ближайшие события.
# Результат объединения субтитров помещается в каталог $out_dir.

use utf8;
use open ':utf8';
use Text::LevenshteinXS;

$time_dir = 'Central-Anime';
$text_dir = 'UNKO-G';
$out_dir = 'merged';

# ----------------------------------------------------------

package Subtitle;

use utf8;
use constant { START => 1, STYLE => 3, TEXT => 9 };

# Создать новый экземпляр Subtitle и загрузить события из файла
sub new {
	my ($class, $input_filename, $output_filename) = @_;
	my $self = [];
	bless( $self, $class);

	# Ищем секцию с диалогами
	open my $IN, $input_filename;
	open my $OUT, '>', $output_filename if $output_filename;
	my $line;
	while ($line = <$IN>) {
		print $OUT $line if $output_filename;
		last if $line =~ m/^\[Events\]/;
	}
	$line = <$IN>;	# Format
	if ($output_filename) {
		print $OUT $line;
		close $OUT;
    }

	# Читаем события из файла в память
	while ($line = <$IN>) {
		$line =~ s/(,,|\s)-(\s|\\N|$)/\1–\2/g;	# Тире вместо дефисов
		last if ($line !~ m/^(Dialogue|Comment)/);
		push @{$self}, [ split( /,/, $line, 10) ];
	}
	close $IN;
	return $self;
}

# Возвращает количество событий
sub count {
	my ($self) = @_;
	return scalar @{$self};
}

# Возвращает событие целиком (как список)
sub event {
	my ($self, $at) = @_;
	return @{$self->[$at]};
}

# Возвращает начальное время заданного события
sub start {
	my ($self, $at) = @_;
	return $self->[$at]->[START];
}

# Возвращает название стиля заданного события
sub style {
	my ($self, $at) = @_;
	return $self->[$at]->[STYLE];
}

# Возвращает текст заданного события
sub text {
	my ($self, $at) = @_;
	return $self->[$at]->[TEXT];
}

# Возвращает поисковый ключ для заданного события (на основе текста)
sub textKey {
	my ($self, $at) = @_;
	my $key = $self->text($at);
	$key =~ s/\{.*\}//g;
	$key =~ s/\\N//g;
	$key =~ s/[[:space:][:punct:]]+//g;
	$key =~ s/ё/е/g;
	return $key;
}

# Возвращает поисковый ключ для заданного события (на основе стиля и текста)
sub matchKey {
	my ($self, $at) = @_;
	return $self->style($at).':'.$self->textKey($at);
}

# ----------------------------------------------------------

package main;

for $time_file (glob $time_dir.'/*.ass') {
	($ep_num) = ($time_file =~ m/- (\d{3})\./);
	($text_file) = glob $text_dir.'/*'.$ep_num.'.ass';
	next if not $text_file;
	($out_file = $time_file) =~ s/$time_dir/$out_dir/;

	$TimeSub = Subtitle->new( $time_file, $out_file);
	$TextSub = Subtitle->new( $text_file);
	open $OUT, '>>', $out_file;

	# Проходим по событиям двух наборов субтитров
	$time_idx = $text_idx = 0;
	$out_of_sync = 0;
	while (1) {
		last if ($time_idx >= $TimeSub->count()) or ($text_idx >= $TextSub->count());

		# Пропускаем пустые события
		if ($TimeSub->textKey($time_idx) eq '') {
			# print "\"$time_file\": skipping empty event at ", $TimeSub->start($time_idx), "\n";
			$time_idx++;
			next;
		}

		# Проверяем синхронизацию субтитров из двух файлов
		$threshold = 0.2 * length( $TimeSub->textKey($time_idx));
		if (distance( $TimeSub->textKey($time_idx), $TextSub->textKey($text_idx)) > $threshold) {
			$out_of_sync = 1;
			# Ищем похожий текст среди ближайшего окружения
DIST:			for ($dist = 1; $dist < 5; $dist++) {
				foreach $inc ($dist, -$dist) {
					next if ($text_idx + $inc < 0) or ($text_idx + $inc >= $TextSub->count());
					if (distance( $TimeSub->textKey($time_idx), $TextSub->textKey($text_idx + $inc)) <= $threshold) {
						$text_idx += $inc;
						$out_of_sync = 0;
						print "\"$time_file\": resynced with delta $inc at ", $TimeSub->start($time_idx), "\n";
						last DIST;
					}
				}
			}
			if ($out_of_sync) {
				# Не удалось синхронизировать, выводим оригинальное событие
				print "\"$time_file\": cannot resync at ", $TimeSub->start($time_idx), " - keeping original text\n";
				$out_of_sync = 0;
				print $OUT join( ',', $TimeSub->event($time_idx) );
				$time_idx++, $text_idx++;
				next;
			}
		}

		# Выводим объединенное событие
		print $OUT join( ',', ($TimeSub->event($time_idx))[0..8] ), ',', $TextSub->text($text_idx);
		$time_idx++, $text_idx++;
	}

	close $OUT;
	system "diff -u \"$time_file\" \"$out_file\" >\"$out_file.diff\"";

}
