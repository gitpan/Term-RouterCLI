#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Term::RouterCLI                                      #
# Class:       Config                                               #
# Description: Methods for building a Router (Stanford) style CLI   #
#                                                                   #
# Written by:  Bret Jordan (jordan at open1x littledot org)         #
# Created:     2011-02-21                                           #
##################################################################### 
#
#
#
#
package Term::RouterCLI::Config;

use 5.8.8;
use strict;
use warnings;

use parent qw(Exporter);
our @EXPORT      = qw();
our @EXPORT_OK   = qw();
our %EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );
our $VERSION     = '0.99_13';

use Config::General();
use File::Copy;


sub new
{
    my $pkg = shift;
    my $class = ref($pkg) || $pkg;  
    
    my $self = {};
    $self->{_sName}                 = $pkg;        # Lets set the object name so we can use it in debugging
    $self->{_sFilename}             = undef;
    $self->{_hConfigData}           = undef;
    $self->{_oConfigFile}           = undef;
    $self->{_iDebug}                = 0;
    
    # Lets overwrite any defaults with values that are passed in
    my %hParameters = @_;
    foreach (keys (%hParameters)) { $self->{$_} = $hParameters{$_}; }

    bless ($self, $class); 
    return $self;
}

sub DESTROY
{
    my $self = shift;
    $self = {};
} 

sub SetFilename 
{ 
    # This method is for setting the filename for the configuration file
    # Required:
    #   string(file name)
    my $self = shift;
    my $parameter = shift;
    $self->{_sFilename} = $parameter;
}

sub LoadConfig
{
    # This method will load the current configuration in to a hash that can be used
    my $self = shift;

    my $oConfig = new Config::General
    (
        -ConfigFile => "$self->{_sFilename}",
        -LowerCaseNames => 1,
        -MergeDuplicateOptions => 1,
        -AutoTrue => 0,
        -ExtendedAccess => 1
    );
    $self->{_oConfigFile} = $oConfig;

    # Lets get all of the configuration in one pass to save disk IO then lets save the data in to the object 
    my %hConfiguration = $oConfig->getall();
    $self->{_hConfigData} = \%hConfiguration;
}

sub ReloadConfig
{
    # This method will reload the current configuration
    my $self = shift;
    
    $self->{_hConfigData} = undef;
    $self->LoadConfig();
}

sub SaveConfig
{
    # This method will save out the hash of the configuration back to the same file.  It will make a backup first
    my $self = shift;

    # Backup configuration first
    $self->BackupConfig();
    
    # Save current configuration
    $self->{_oConfigFile}->save_file("$self->{_sFilename}", $self->{_hConfigData});
}

sub BackupConfig
{
    # This method will make a backup of the current configuration file
    my $self = shift;
    my $sOriginalFile = $self->{_sFilename};
    my $sBackupFile = $self->{_sFilename} . ".bak";
    copy ($sOriginalFile, $sBackupFile);
}

return 1;
