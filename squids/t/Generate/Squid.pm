package Generate::Squid;
use strict;
use warnings;
use POSIX qw/strftime/;
use Time::Piece;
use List::Util qw/first/;
use Carp;



# ISO_3166-1 country codes ( Alpha-2 column in table located here => http://en.wikipedia.org/wiki/ISO_3166-1 )
# this list was generated by copy-pasting that table and afterwards filtering it like this
# cat /tmp/country_codes | perl -ne '/^.*?\s+([A-Z][A-Z])\s+/ && print "$1,"'
# 
# a total of 250 countries (the first 6 are sorted descending by population)
# (also added XX in there so of those many country codes one is XX)
# our @ALL_COUNTRY_CODES = qw/CH IN US ID BR PK RU AF AX AL DZ AS AD AO AI AQ AG AR AM AW AU AT AZ BS BH BD BB BY BE BZ BJ BM BT BO BQ BA BW BV IO BN BG BF BI KH CM CA CV KY CF TD CL CN CX CC CO KM CG CD CK CR CI HR CU CW CY CZ DK DJ DM DO EC EG SV GQ ER EE ET FK FO FJ FI FR GF PF TF GA GM GE DE GH GI GR GL GD GP GU GT GG GN GW GY HT HM VA HN HK HU IS IR IQ IE IM IL IT JM JP JE JO KZ KE KI KP KR KW KG LA LV LB LS LR LY LI LT LU MO MK MG MW MY MV ML MT MH MQ MR MU YT MX FM MD MC MN ME MS MA MZ MM NA NR NP NL NC NZ NI NE NG NU NF MP NO OM PW PS PA PG PY PE PH PN PL PT PR QA RE RO RW BL SH KN LC MF PM VC WS SM ST SA SN RS SC SL SG SX SK SI SB SO ZA GS SS ES LK SD SR SJ SZ SE SY TW TJ TZ TH TL TG TK TO TT TN TR TM TC TV UG UA AE GB UM UY UZ VU VE VN VG VI WF EH YE ZM ZW XX/;
# 
# Update: replaced list of geocode country codes with the one found in the source of the official Perl API for MaxMind's Geocode DB  http://cpansearch.perl.org/src/BORISZ/Geo-IP-PurePerl-1.25/lib/Geo/IP/PurePerl.pm
#
# Update: We have some custom codes in wikistats, -P means IPv6 which is marked unknown because Maxmind doesn't support them yet

our @ALL_WIKISTATS_CUSTOM_CODES  = qw/-P -- XX/;
our @ALL_WIKISTATS_REGULAR_CODES = qw/A1 A2 AB MF AQ BL G2 GF KO O1 TE TK BV IO TF AD AE AF AG AI AL AM AN AO AP AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BM BN BO BR BS BT BW BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET EU FI FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR ST SV SY SZ TC TD TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW/;
our @ALL_COUNTRY_CODES          = (@ALL_WIKISTATS_CUSTOM_CODES,@ALL_WIKISTATS_REGULAR_CODES);
#
# This module is written to generate valid Squid log lines
# in order for them to be used inside tests
#
# This will decrease the need to hardcode log values inside the logs.
# This is in particular aimed at tests which require a lot of log lines
# which are harder to maintain by hardcoding them into test files.
#
#
#
#  SYNOPSIS:
#
#  my $o = Generate::Squid->new({
#     start_date => "2012-10-01"       ,
#     prefix     => "sampled-1000.log-",
#     output_dir => "/tmp/generated_logs",
#  });
#  $o->generate_line({ geocode=>"CA"  }) for 1..900;
#  $o->generate_line({ geocode=>"US"  }) for 1..900;
#  $o->generate_line({ geocode=>"BR"  }) for 1..500;
#  $o->dump_to_disk_and_increase_day;
#  $o->generate_line();
#  $o->dump_to_disk_and_increase_day;
#
#  This way we've just generated 900 Canada entries and 900 US entries and 500 Brazil entries.
#
#  After running this you will have two files   sampled-1000.log-20121001  and  sampled-1000.log-20121002,
#  the first with 2300 entries, the second with just one entry, and you will be ready to parse them with wikistats.
#

sub new {
  my ($class_name,$params) = @_;

  my $strptime_errors = (sub{undef $@; eval{ Time::Piece->strptime($params->{start_date},"%Y-%m-%d"); }; $@; })->();

  confess "[ERROR] Expected params hashref as argument"
    unless ref($params) eq "HASH";

  confess "[ERROR] Expected output_dir"
    unless $params->{output_dir};

  confess "[ERROR] Expected start_date param"
    unless $params->{start_date};

  confess "[ERROR] Expected prefix param (filename prefix of logs that will be generated)"
    unless $params->{prefix};

  confess "[ERROR] Invalid start date (please use YYYY-MM-DD format, for example 2012-10-01)"
    if $strptime_errors;

  confess "[ERROR] Output directory does not exist"
    if ! -d $params->{output_dir};


  my $self = bless {},$class_name;

  $self->{buffer}           = "";
  $self->{prefix}           = $params->{prefix};
  $self->{current_datetime} = $params->{start_date}."T00:00:00.000";
  $self->{output_dir}       = $params->{output_dir};


  return $self;
};



sub __parse_self_current_datetime {
  my ($self) = @_;
  return Time::Piece->strptime($self->{current_datetime},"%Y-%m-%dT%H:%M:%S.000");
};



# used by generate_line in order to increase the time for the next line
# WARNING: by doing this (which is done implicitly) there are only 82800 entries which you can have in one day
# If you don't dump to disk before that, you will have problems(depending on what you're doing).
sub __increase_second {
  my ($self) = @_;
  #takes into account the milliseconds at the end
  my $tp_object = $self->__parse_self_current_datetime;
  $tp_object++;  #ADDS ONE SECOND
  $self->{current_datetime} = $tp_object->datetime.".000";
};

sub __increase_day  {
  my ($self) = @_;
  #takes into account the milliseconds at the end

  # Reset HMS of date
  $self->{current_datetime} =~ s/T.*$/T00:00:00.000/g;
  my $tp_object = $self->__parse_self_current_datetime;
  #ADDS ONE DAY
  $tp_object+=24 * 3600;
  $self->{current_datetime} = $tp_object->datetime.".000";
};


# Generate a random ip
# Will be used in case we specify client_ip to be
# "random_ip" in generate_line 
sub __generate_random_ipv4 {
  return 
    join(".",map { 1+int(rand(255)) } 1..4);
};

sub __generate_random_ipv6 {
  return
    sprintf(
        join(":",map{"%04x"}1..8),     # format with 8 groups of padded-hex numbers separated by :
        map{ int(rand(16**4-1)) }1..8  # arguments are 8 random numbers between 0 and 16**4-1
    );
};

sub __generate_random_country {
  return
    $ALL_COUNTRY_CODES[int(rand(@ALL_COUNTRY_CODES))];
};


sub dump_to_disk_and_increase_day {
  my ($self) = @_;

  my $tp_object = $self->__parse_self_current_datetime;
  my $filename_date = $tp_object->ymd;
  $filename_date =~ s/-//g;

  my $output_dir   =  $self->{output_dir};
  my $log_filename =  $self->{prefix}.$filename_date;  
  my $log_fullpath = "$output_dir/$log_filename";

  open my $log_fh,">",$log_fullpath;

  print $log_fh $self->{buffer};

  # reset buffer and close filehandle
  close($log_fh);
  $self->{buffer} = "";
  $self->__increase_day;
};


sub generate_line {
  my ($self,$params) = @_;

  #1)squid_hostname
  #2)seq_number
  #3)current_time
  #4)request_service_time
  #5)client_ip
  #6)squid_request_status
  #7)reply_size
  #8)request_method
  #9)url
  #10)squid_hierarchy_status
  #11)mime_content_type
  #12)referer_header
  #13)x_forwarded_for_header
  #14)user_agent_header
  #15)accept_language_header
  #16)x_wap_profile_header
  #17)geocoding (currently provided by the output of udp-filter)

  # Example of squid log line 
  # cp1004.eqiad.wmnet 1811174556 2012-09-30T07:03:23.308 242 131.123.112.2 TCP_MEM_HIT/200 66918 GET http://en.wikipedia.org/wiki/Harry_Potter_and_the_Half-Blood_Prince_(film) NONE/- text/html http://en.wikipedia.org/wiki/Phil_of_the_Future - Mozilla/5.0%20(Windows%20NT%206.1;%20WOW64;%20rv:15.0)%20Gecko/20100101%20Firefox/15.0.1 US



  if($params->{geocode}) {
    confess "[ERROR] Invalid country code"
      unless first { $_ eq $params->{geocode} } @ALL_COUNTRY_CODES;
  };

  my $default = {
    squid_hostname         => "cp1004.eqiad.wmnet",
    request_service_time   => "242",
    client_ip              => "111.22.33.44",
    squid_request_status   => "TCP_MEM_HIT/200",
    reply_size             => "66918",
    request_method         => "GET",
    url                    => "http://en.wikipedia.org/wiki/Harry_Potter_and_the_Half-Blood_Prince_(film)",
    squid_hierarchy_status => "NONE/-",
    mime_content_type      => "text/html",
    referer_header         => "http://en.wikipedia.org/wiki/Phil_of_the_Future",
    x_forwarded_for_header => "-",
    user_agent_header      => "Mozilla/5.0%20(Windows%20NT%206.1;%20WOW64;%20rv:15.0)%20Gecko/20100101%20Firefox/15.0.1",
    geocode                => "US",
  };

  my $field_client_ip;
  my $field_seqnumber              = int(181_117_455 + rand(500_000));
  my $field_squid_hostname         = $default->{squid_hostname}; #hardcoded
  my $field_current_time           = $self->{current_datetime}; # COMPUTED

  if(defined($params->{client_ip})) {
    if(      $params->{client_ip} eq "random_ipv4") {
     $field_client_ip  = $self->__generate_random_ipv4;
    } elsif ($params->{client_ip} eq "random_ipv6") {
      $field_client_ip = $self->__generate_random_ipv6;
    } else {
      $field_client_ip = $params->{client_ip};
    };
  } else {
    $field_client_ip = $default->{client_ip};
  };

  my $field_request_service_time   = $params->{request_service_time}   // $default->{request_service_time}; # hardcoded
  my $field_squid_request_status   = $params->{squid_request_status}   // $default->{squid_request_status};  # hardcoded
  my $field_reply_size             = $params->{reply_size}             // $default->{reply_size}; #hardcoded
  my $field_request_method         = $params->{request_method}         // $default->{request_method};
  my $field_url                    = $params->{url}                    // $default->{url};
  my $field_squid_hierarchy_status = $params->{squid_hierarchy_status} // $default->{squid_hierarchy_status};
  my $field_mime_content_type      = $params->{mime_content_type}      // $default->{mime_content_type};
  my $field_referer_header         = $params->{referer_header}         // $default->{referer_header};
  my $field_x_forwarded_for_header = $params->{x_forwarded_for_header} // $default->{x_forwarded_for_header};
  my $field_user_agent_header      = $params->{user_agent_header}      // $default->{user_agent_header};
  my $field_geocode                = $params->{geocode}                // $default->{geocode};

  # Currently wikistats accepts 15-field entries, geocode field included (will have to talk to Erik about fields
  # 15 and 16 in the description above because we seem to be dropping those at the 15-field-count-check)
  my $raw_logline = join(" ",
    $field_squid_hostname        ,
    $field_seqnumber             ,
    $field_current_time          ,
    $field_request_service_time  ,
    $field_client_ip             ,
    $field_squid_request_status  ,
    $field_reply_size            ,
    $field_request_method        ,
    $field_url                   ,
    $field_squid_hierarchy_status,
    $field_mime_content_type     ,
    $field_referer_header        ,
    $field_x_forwarded_for_header,
    $field_user_agent_header     ,
    $field_geocode               ,
  );

  $self->{buffer} .= "$raw_logline\n";
  $self->__increase_second;
};


1;