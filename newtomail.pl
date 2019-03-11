#!/usr/bin/env perl

##
# Pobiera informacje techniczne z komunikaty.nazwa.pl i wysyla powiadomienie mailem

use strict;
use warnings;
use utf8;
use Data::Dumper;

use LWP::Simple;
use XML::Simple;
use File::Slurp;
use DateTime;
use Net::SMTP;
use Encode;

# Ustawienia
my $root = '/home/user/komunikatynazwa'; ## zmien !
my $sourceUrl = 'http://feeds.feedburner.com/KomunikatyTechniczneNazwapl?format=xml';
my $sourceFile = 'test/feed-static.xml';
my $noticeEmail = 'xxxxxx_admin_email@o2.pl';
my $dateTimeStamp = date_time_stamp('houronly');
my $stamp = date_time_stamp();
my $dateStamp = date_time_stamp('dateonly');
my $dateTimeStampNoSpace = date_time_stamp('nospace');
my $stampFile='';
my $logFile = $root .'/logs/logfile.txt';

print "[ Czas: $stamp  ]\n";
print "[ Stamp date + time: $dateTimeStamp ]\n";
print "[ Stamp date: $dateStamp ]\n";


## TODO

## Akcja
print "[ -START- Czyczczenie starych plikow TMPF. ]\n";
string_to_log("[ $stamp | Czyszczenie starych plikow TMPF ]\n");
clean_tmpf();

print "[ -- GET $sourceUrl ]\n";
my $data = get( $sourceUrl );

#my $data = read_file( $sourceFile ); # pobranie danych z pliku do testow
my $parser = new XML::Simple;

print "[ -PARSING- ]\n";
string_to_log("[ $stamp | PARSING -> $sourceUrl ]\n");
my $xml = $parser->XMLin( $data );

## dane z parsera do podgladu
#print Dumper( @{$xml->{'channel'}->{'item'}} );

## Petla glowna po wczytanych komunikatach
for my $statement ( @{$xml->{'channel'}->{'item'}} ) {

    my $pubDate = $statement->{'pubDate'};
    my $pubDateNoSpaces = $pubDate =~ s/\s//gr;
    	$pubDateNoSpaces =~ s/\+0000//g;
    	$pubDateNoSpaces =~ s/\:|\,//g;
    	
    # bierzacy plik wysylki
    $stampFile = $root .'/'. $pubDateNoSpaces .'.tmpf';
    	
    	
    print "[ Data publikacji bez spacji: $pubDateNoSpaces ]\n";
    print "[ Nazwa pliku wysylki: $stampFile ]\n";
    
    # jezeli data publikacji pasuje do znacznika biezacej daty i plik wysylki nie istnieje
    if ( $pubDate =~ /$dateStamp/ && !-e $stampFile ) {
    
	print "[ -#---------------------------------------------------------- ]\n";
        print Dumper( $statement );
        string_to_log("[ $stamp | $pubDate pasuje do $dateStamp ]\n");
        
        # jezeli nie ma pliku TMPF z danej godziny
        if ( !-e $stampFile ) {
    	    print "[ Nowy komunikat - wysylam powiadomienie! ]\n";
    	    
    	    # tresc powiadomienia w HTML'u
    	    my $msg = $statement->{'title'} .' '. $statement->{'description'} .' <a href="'. $statement->{'link'} .'">'. $statement->{'link'} .'</a>';
        
    	    # wyslanie powiadomienia
    	    sendmail($noticeEmail, 'perl@dev-napad.pl', 'Nowy komunikat Nazwa.pl: ['. $statement->{'title'} .' ]', $msg);
    	    
    	    string_to_log("[ $stamp | Wyslane powiadomienie: $statement->{'title'} ]\n");
    	    
    	    # plik wysylki
    	    
    	    #$stampFile = $root .'/'. $pubDateNoSpaces .'.tmpf';
    	    write_file($stampFile, $dateTimeStamp);
        }
	print "[ -#---------------------------------------------------------- ]\n";
    } 
    #else {
	##
	# debug
    	#print "[ -#---------------------------------------------------------- ]\n";
    	#print "[ !! | Data publikacji nie pasuje do znacznika biezacej daty | ]\n";
    	#print "[      Data publikacji: $pubDate != data biezaca: $dateTimeStamp ]\n";
    	#print "[ -#---------------------------------------------------------- ]\n";
	#string_to_log("[ $stamp | Data publikacji nie pasuje: $pubDate != data biezaca: $dateStamp LUB istnieje plik wysylki $stampFile ]\n");
    #}
}

## Koniec
string_to_log("[ -------------------------------------------------------------------------------------- ]\n");


## funkcje dodatkowe
sub sendmail {
    ##
    # Wysyla powiadomienie e-mail
    
    my $mail = $_[0]; # odbiorca
    my $mailFrom = $_[1]; # nadawca
    my $subject = $_[2]; # temat
    my $message = $_[3]; # tresc
    my $smtpHost = '127.0.0.1';
    my $retval = '0'; # status wykonania
    
    # instancja mailera
    my $smtp = Net::SMTP->new( $smtpHost );
        $smtp->mail( $mailFrom );
        $smtp->to( $mail );
        
    # wysylka
    $smtp->data();
    $smtp->datasend("To: ". $mail ."\n");
    $smtp->datasend("Subject: ". $subject ."\n");
    $smtp->datasend("User-Agent: Monit AT dev-napad.pl Daemon\n");
    $smtp->datasend("MIME-Version: 1.0 \nContent-Type: text/html; charset=utf-8\n");
    $smtp->datasend("\n");
    $smtp->datasend("\n". $message ."\n");
    $smtp->dataend();
    $retval = $smtp->quit;
    
}

sub date_time_stamp {
    ##
    # DateTime
    # Zwraca czastkowy znacznik czasu w formacie wzorca 'Thu, 15 Dec 2016 15:02'
    # Mon, 06 Mar 2017 15:07:07 +0000 != Tue, 7 Mar 2017 14
    # edit: dodana lokalna strefa czasowa
    
    my $param = shift(@_);
    my $dt = DateTime->now;
	$dt->set_time_zone( 'Europe/Warsaw' );
    my $stamp = '';
    my $downame = $dt->day_abbr;
    my $mday = $dt->day;
	if (length($mday) != 2) {
	    $mday = '0'.$mday;
	}
    my $mname = $dt->month_abbr;
    my $year = $dt->year;
    my $hour   = $dt->hour;
	if (length($hour) != 2) {
	    $hour = '0'.$hour;
	}
    my $minute = $dt->minute;

    
    if ( $param eq 'nospace' ) {
        $stamp = $downame . $mday . $mname . $year . $hour . $minute;
    } elsif($param eq 'houronly') {
	$stamp = $downame .', '. $mday .' '. $mname .' '. $year .' '. $hour;
	
    } elsif($param eq 'dateonly') {
	$stamp = $downame .', '. $mday .' '. $mname .' '. $year;
    } else {
	$stamp = $downame .', '. $mday .' '. $mname .' '. $year .' '. $hour .':'. $minute;
    }
    
    return $stamp;
}

sub clean_tmpf {
    ##
    # Czysci nieaktualne pliki .tmpf
    # opcja http://search.cpan.org/~rclamp/File-Find-Rule-0.34/lib/File/Find/Rule.pm
    
    my $stampDir = $root;
    my $dateStampNoSpaces = $dateStamp =~ s/\s|\,//gr;
    
    print "[ Biezacy stamp bez spacji: $dateStampNoSpaces ]\n";
    
    print "[ Czyszce zawartosc: $stampDir ]\n";
    
    opendir(TMPFILEDIR, $stampDir) || die "can't opendir $stampDir: $!";
    my @files = grep { /\.tmpf$/ } readdir( TMPFILEDIR ); 
    closedir(TMPFILEDIR);
    
    for my $filename ( @files ) {
	if ( $filename !~ /$dateStampNoSpaces/ ) {
	    print "[ plik tmpf --- $filename -- usuwam ]\n";
	    unlink $stampDir .'/'. $filename;
	} else {
	    print "[ plik tmpf --- $filename -- pomijam ]\n";
	}
    }
}

sub string_to_log {
    ##
    # Zapisuje ciag znakow do pliku
    my $string = ($_[0]) ? $_[0] : '';
    my $file = ($_[1]) ? $_[1] : $logFile;
    
    my $fh = IO::File->new(">> $file");

    if (defined $fh) {
	print $fh $string;
	$fh->close;
    }
}