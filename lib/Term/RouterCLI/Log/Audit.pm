#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Term::RouterCLI::Log                                 #
# Class:       Audit                                                #
# Description: Methods for building a Router (Stanford) style CLI   #
#                                                                   #
# Written by:  Bret Jordan (jordan at open1x littledot org)         #
# Created:     2011-02-21                                           #
##################################################################### 
#
#
#
#
package Term::RouterCLI::Log::Audit;

use 5.8.8;
use strict;
use warnings;

use parent qw(Exporter);;
our @EXPORT      = qw();
our @EXPORT_OK   = qw();
our %EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );
our $VERSION     = '0.99_13';

# Define our parent
use parent qw(Term::RouterCLI::Log);


use POSIX qw(strftime);

# TODO Work out how to rotate files and keep data longer instead of just pruning it

sub StartAuditLog
{
    # This method is for starting the audit log. 
    my $self = shift;
    print "--DEBUG $self->{_sName}-- ### Entering StartAuditLog ###\n" if ($self->{_iDebug} >= 1);
    my $retval = $self->ReadLogFile();
    
    if ($retval == 1) { $self->WriteExistingLogData(); }
    print "--DEBUG $self->{_sName}-- ### Leaving StartAuditLog ###\n" if ($self->{_iDebug} >= 1);
}

sub RecordToLog
{
	# This method will record an event in to the audit log
	# Required:
	#  hash_ref (prompt=>current prompt, commands=>command to be logged)
	my $self = shift;
	my $hParameter = shift;
	 
	print "--DEBUG $self->{_sName}-- ### Entering RecordToLog ###\n" if ($self->{_iDebug} >= 1);
	
    unless (defined $self->{_oFileHandle}) { $self->OpenFileHandle("A"); }
    my $FILE = ${$self->{_oFileHandle}};
    print "--DEBUG $self->{_sName}-- File Handle: $FILE\n" if ($self->{_iDebug} >= 3);
    
    my $sTimeStamp = strftime "%Y-%b-%e %a %H:%M:%S", localtime;
    
    my $sOutput = "($sTimeStamp) \[$hParameter->{username}\@$hParameter->{tty}\] \[$hParameter->{prompt}\] $hParameter->{commands}";
    print "--DEBUG $self->{_sName}-- sOutput: $sOutput\n" if ($self->{_iDebug} >= 3);
    
    print $FILE "$sOutput\n";
    $FILE->sync;
    print "--DEBUG $self->{_sName}-- ### Leaving RecordToLog ###\n" if ($self->{_iDebug} >= 1);
}

return 1;
