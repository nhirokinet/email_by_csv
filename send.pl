#!/usr/bin/perl

use strict;
use Net::SMTPS;
use Term::ReadKey;
use utf8;
use Jcode;
use Text::CSV_XS;
use Email::Date::Format qw(email_date);

our $smtphost ;
our $smtpport ;
our $smtpssl ;
our $smtpehlo ;
our $smtplogin ;
our $smtpusername ;
our $smtppasswd ;
our $mailfrom;
our $mailto;
our $subject;
my $body = '';

my $send_real = 0;
if($ARGV[0] eq 'send') {
	$send_real = 1;
}
open (LOGFH, '>>log/send.log') || die ('fileload');

open (FH, '<body.txt') || die ('fileload');

while(my $l = <FH>){
	$body .= $l;
}
close (FH);

require 'setting.pl';
require 'mailsetting.pl';

if($send_real){
	if($smtpusername eq '') {
		print 'Username: ';
		$smtpusername = <STDIN>;
		chomp($smtpusername);
	}

	if($smtppasswd eq '') {
		print 'Password: ';
		ReadMode('noecho');
		$smtppasswd = <STDIN>;
		chomp($smtppasswd);
		ReadMode(0);
		print "\n";
	}
}
print "\n";

my $fh = IO::File->new('data.csv') || die('fail');
my $csv = Text::CSV_XS->new({binary=>1});

my @columnlist = @{$csv->getline($fh)};

until($fh->eof){
	if(!$send_real){
		print "\n\n--------\n";
	}
	my @data = @{$csv->getline($fh)};
	my $mailto = $data[0];

	next if(!$mailto);
	next if(length($mailto)<3);

	my $mybody = $body;

	for(my $i=0; $i<=$#columnlist; $i++) {
		my $k = ($columnlist[$i]);
		my $v = ($data[$i]);

		$mybody =~ s/\$\{\Q$k\E\}/$v/g;
	}

	print "Sending to: ".$mailto."\n";

	my $subjectenc = Jcode->new($subject)->mime_encode;
	my $bodyenc = Jcode->new($mybody)->jis;

	if(!$send_real){
		$subjectenc = $subject;
		$bodyenc = $mybody;
	}

	my $message = '';
	$message .= 'From: '. $mailfrom. "\n";
	$message .= 'To: '. $mailto."\n";
	$message .= 'Subject: '. $subjectenc."\n";
	$message .= 'Date: '.email_date."\n";
	$message .= "Mime-Version: 1.0\n";
	$message .= "Content-Type: text/plain; charset=\"iso-2022-jp\"\n";
	$message .= "Content-Transfer-Encoding: 7bit\n";
	$message .= "\n";
	$message .= $bodyenc;
	
	if($send_real){
		my $smtp = Net::SMTPS->new($smtphost, Port=>$smtpport, User=>$smtpusername, Password=>$smtppasswd, doSSL=>$smtpssl, ehlo=>$smtpehlo);
		if(!$smtp){
			die 'SMTP Error';
		}
		$smtp->auth($smtpusername, $smtppasswd);

		$smtp->mail($mailfrom);
		if($smtp->to($mailto)){
			$smtp->data();
			$smtp->datasend($message);
			$smtp->dataend();
			print LOGFH "Send \"".$subject."\"to ".$mailto."\n";
			print "Sent.\n";
		}else{
			print $smtp->message();
		}
		$smtp->quit();
	} else {
		print "--\n";
		print $message;
	}
}
$fh->close;
close(LOGFH);
