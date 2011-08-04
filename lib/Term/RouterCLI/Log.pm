#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Term::RouterCLI                                      #
# Class:       Log                                                  #
# Description: Methods for building a Router (Stanford) style CLI   #
#                                                                   #
# Written by:  Bret Jordan (jordan at open1x littledot org)         #
# Created:     2011-04-26                                           #
##################################################################### 
#
#
#
#
package Term::RouterCLI::Log;

use 5.8.8;
use strict;
use warnings;

use parent qw(Exporter);
our @EXPORT      = qw();
our @EXPORT_OK   = qw();
our %EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );
our $VERSION     = '0.99_13';

use FileHandle;

sub new
{
    my $pkg = shift;
    my $class = ref($pkg) || $pkg;  

    my $self = {};
    $self->{_sName}                 = $pkg;         # Lets set the object name so we can use it in debugging
    $self->{_bEnabled}              = 1;
    $self->{_oParent}               = undef;
    $self->{_sFilename}             = undef;
    $self->{_iFileLength}           = 500;
    $self->{_iMaxFileLength}        = 50000;        # Define an upper bound for sanity sakes
    $self->{_oFileHandle}           = undef;
    $self->{_aCurrentLogData}       = undef;
    $self->{_iCurrentLogSize}       = undef;
    $self->{_iDebug}                = 0;            # 1 = Method flow, 2 = Action notes, 3 = Variable values, 5 = Array/Hash dumps
        
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

sub Enable
{
    # This method will enable this log method
    my $self = shift;
    $self->{_bEnabled} = 1;
}

sub Disable
{
    # This method will disable this log method
    my $self = shift;
    $self->{_bEnabled} = 0;
}

sub ExpandTildesInFilename
{
    # This method will expand any tildes that are in the file name so that it will work right
    my $self = shift;
    
    print "--DEBUG $self->{_sName}-- ### Entering ExpandTildesInFilename ###\n" if ($self->{_iDebug} >= 1); 
    if (defined $self->{_sFilename}) 
    {
        $self->{_sFilename} =~ s/^~([^\/]*)/$1?(getpwnam($1))[7]:$ENV{HOME}||$ENV{LOGDIR}||(getpwuid($>))[7]/e;
    }    
    print "--DEBUG $self->{_sName}-- ### Leaving ExpandTildesInFilename ###\n" if ($self->{_iDebug} >= 1); 
}

sub SetFilename
{
    # This method will set the filename for this logging method
    # Required:
    #   string (filename)
    my $self = shift;
    my $parameter = shift;

    print "--DEBUG $self->{_sName}-- ### Entering SetFilename ###\n" if ($self->{_iDebug} >= 1);    
    if (defined $parameter)
    {
        $self->{_sFilename} = $parameter;
        $self->ExpandTildesInFilename();
    }
    print "--DEBUG $self->{_sName}-- ### Leaving SetFilename ###\n" if ($self->{_iDebug} >= 1);    
}

sub SetFileLength
{
    # This method will set the length of the history file on disk which is limited to 50000 for sanity reasons
    # Required:
    #   integer (length)
    my $self = shift;
    my $parameter = shift;
    print "--DEBUG $self->{_sName}-- ### Entering SetFileLength ###\n" if ($self->{_iDebug} >= 1);
    if (($parameter =~ /^\d+$/) && ($parameter > 0) && ($parameter < $self->{_iMaxFileLength}))
    {
        $self->{_iFileLength} = $parameter;
    } 
    print "--DEBUG $self->{_sName}-- ### Leaving SetFileLength ###\n" if ($self->{_iDebug} >= 1);
}

sub SetCurrentLogSize
{
    # This method will capture the current size of the logging data array
    my $self = shift;
    print "--DEBUG $self->{_sName}-- ### Entering SetCurrentLogSize ###\n" if ($self->{_iDebug} >= 1);
    $self->{_iCurrentLogSize} = @{$self->{_aCurrentLogData}};
    print "--DEBUG $self->{_sName}-- _iCurrentLogSize: $self->{_iCurrentLogSize}\n" if ($self->{_iDebug} >= 3);
    print "--DEBUG $self->{_sName}-- ### Entering SetCurrentLogSize ###\n" if ($self->{_iDebug} >= 1);
}

sub OpenFileHandle
{
    # This method will create a file handle for the audit log
    # Required:
    #   string (handle type R=Read, W=Write, A=Append)
    my $self = shift;
    my $parameter = shift;
    my $FILE = undef;
    
    print "--DEBUG $self->{_sName}-- ### Entering OpenFileHandle ###\n" if ($self->{_iDebug} >= 1);
    
    # Make sure the file name and size have been defined
    if ((defined $self->{_sFilename}) && ($self->{_iFileLength} > 0))
    {
        # Open file depending on what we need.  I tried to just use +>> but that does not truncate and clean
        # out the file so it makes it so I can not purge old data
        if ($parameter eq "W")
        {
            print "--DEBUG $self->{_sName}-- ### Opening file hand for writing ### \n" if ($self->{_iDebug} >= 2);
            $FILE = new FileHandle(">$self->{_sFilename}") || warn "Can not open " . $self->{_sFilename} . " for writing $!\n";
        } 
        elsif ($parameter eq "A")
        {
            print "--DEBUG $self->{_sName}-- ### Opening file hand for appending ### \n" if ($self->{_iDebug} >= 2);
            $FILE = new FileHandle(">>$self->{_sFilename}") || warn "Can not open " . $self->{_sFilename} . " for appending $!\n";
        }
        else
        {
            print "--DEBUG $self->{_sName}-- ### Opening file hand for reading ### \n" if ($self->{_iDebug} >= 2);
            $FILE = new FileHandle("<$self->{_sFilename}") || warn "Can not open " . $self->{_sFilename} . " for reading $!\n";
        }
        $FILE->autoflush(1);
        $self->{_oFileHandle} = \$FILE;
        print "--DEBUG $self->{_sName}-- _oFileHandle: ${$self->{_oFileHandle}}\n" if ($self->{_iDebug} >= 3);
    }
    print "--DEBUG $self->{_sName}-- ### Leaving OpenFileHandle ###\n" if ($self->{_iDebug} >= 1);
}

sub CloseFileHandle
{
    # This method will close the file handle
    my $self = shift;
    print "--DEBUG $self->{_sName}-- ### Entering CloseFileHandle ###\n" if ($self->{_iDebug} >= 1);

    if (defined $self->{_oFileHandle})
    {
        print "--DEBUG $self->{_sName}-- ### _oFileHandle: ${$self->{_oFileHandle}} ###\n" if ($self->{_iDebug} >= 3);
        ${$self->{_oFileHandle}}->close;
    }
    $self->{_oFileHandle} = undef;
    print "--DEBUG $self->{_sName}-- ### Leaving CloseFileHandle ###\n" if ($self->{_iDebug} >= 1);
}

sub ReadLogFile
{
    # This method will read the current log file if it exists and we need to do this before
    # we open the standard file handle as it will be setup for writing, and this one is for reading.
    # Return:
    #   0 = nothing was read
    #   1 = a log file was read
    my $self = shift;
    my $retval = 0;
    
    print "--DEBUG $self->{_sName}-- ### Entering ReadLogFile ###\n" if ($self->{_iDebug} >= 1);
    
    # If the log file is already on the system lets read its current contents in to memory
    if ((defined $self->{_sFilename}) && (-r $self->{_sFilename}))
    {
        $self->OpenFileHandle("R");
        my $FILE = ${$self->{_oFileHandle}};
        my @aCurrentLogData = <$FILE>;
        my @aNewLogData;
        foreach (@aCurrentLogData)
        {
            chomp();
            push(@aNewLogData,$_);
        }

        $self->{_aCurrentLogData} = \@aNewLogData;
        if ($self->{_iDebug} >= 5)
        {
            foreach (@{$self->{_aCurrentLogData}}) { print "--DEBUG $self->{_sName}-- _aCurrentLogData: $_\n"; }
        }

        # Lets capture the current log size so we have it
        $self->SetCurrentLogSize();

        $self->CloseFileHandle();
        $retval = 1;
    }
    print "--DEBUG $self->{_sName}-- ### Leaving ReadLogFile with retval: $retval ###\n" if ($self->{_iDebug} >= 1);
    return $retval;
}

sub WriteExistingLogData
{
    # This method will write out the existing log data to the file making sure we keep in mind the
    # file lengths
    my $self = shift;
    print "--DEBUG $self->{_sName}-- ### Entering WriteExistingLogData ###\n" if ($self->{_iDebug} >= 1);

    $self->OpenFileHandle("W");
    my $FILE = ${$self->{_oFileHandle}};
    print "--DEBUG $self->{_sName}-- FILE: $FILE\n" if ($self->{_iDebug} >= 3);
    
    my $iArrayOffsetNumber = 0;
    
    # If there are more lines in the log data than the max file length then we should only save so
    # many lines so lets back down from the end and set an offset from which to start so that we 
    # are not starting from array index 0. This is needed as the newest commands are at the end of 
    # the array/buffer
    if ($self->{_iFileLength} < $self->{_iCurrentLogSize})
    {
        $iArrayOffsetNumber = $self->{_iCurrentLogSize} - $self->{_iFileLength};
        print "--DEBUG $self->{_sName}-- iArrayOffsetNumber: $iArrayOffsetNumber\n" if ($self->{_iDebug} >= 3);
    }
    
    # Since arrays start at zero, we need to minus one off the end of the History Buffer Size
    foreach ($iArrayOffsetNumber..$self->{_iCurrentLogSize}-1)
    {
        print "--DEBUG $self->{_sName}-- aCurrentLogData: $self->{_aCurrentLogData}->[$_]\n" if ($self->{_iDebug} >= 5);
        print $FILE "$self->{_aCurrentLogData}->[$_]\n";
    }
    $self->CloseFileHandle();
    print "--DEBUG $self->{_sName}-- ### Leaving WriteExistingLogData ###\n" if ($self->{_iDebug} >= 1);
    return;
}

sub ClearExistingLogData
{
    # This method will clear out all existing log data from the array_ref in memory
    my $self = shift;
    $self->{_aCurrentLogData} = undef;
}

return 1;
