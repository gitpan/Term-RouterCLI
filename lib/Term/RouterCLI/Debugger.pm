#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Term::RouterCLI                                      #
# Class:       Debugger                                             #
# Description: Methods for building a Router (Stanford) style CLI   #
#                                                                   #
# Written by:  Bret Jordan (jordan at open1x littledot org)         #
# Created:     2011-08-24                                           #
##################################################################### 
#
#
#
#
package Term::RouterCLI::Debugger;

use 5.8.8;
use strict;
use warnings;
use Log::Log4perl;

our $VERSION     = '0.99_15';
$VERSION = eval $VERSION;



sub new
{
    my $pkg = shift;
    my $class = ref($pkg) || $pkg;  

    my $self = {};
    $self->{'_sName'}               = $pkg;         # Lets set the object name so we can use it in debugging
    bless ($self, $class);
    
    # Lets send any passed in arguments to the _init method
    $self->_init(@_);
    return $self;
}

sub _init
{
    my $self = shift;
    my %hParameters = @_;

    $self->{'_iDebug'}              = 0;            # This is for internal debugger debugging

    # Lets overwrite any defaults with values that are passed in
    if (%hParameters)
    {
        foreach (keys (%hParameters)) { $self->{$_} = $hParameters{$_}; }
    }
}

sub DESTROY
{
    my $self = shift;
    $self = {};
} 



# ----------------------------------------
# Public Methods 
# ----------------------------------------
sub GetLogger
{
    # This method is a helper method to get the Log4perl logger object
    my $self = shift;
    my $object = shift;
    my $package = ref($object);
    my @data = caller(1);
    my $caller = (split "::", $data[3])[-1];
    my $sLoggerName = $package . "::" . $caller;

    print "+++ DEBUGGER +++ $sLoggerName\n" if ($self->{'_iDebug'} == 1);

    return Log::Log4perl->get_logger("$sLoggerName");
}

sub DumpArray
{
    # This method is for dumping the contents of an array
    # Required:
    #   array_ref   (array of values)
    # Return:
    #   string_ref  (data from array)
    my $self = shift;
    my $parameter = shift;
    my $sStringData = "";
    
    $sStringData .= "\t";
    foreach (@$parameter)
    {
        $sStringData .= "$_, ";
    }
    $sStringData .= "\n";
    return \$sStringData;
}

sub DumpHashKeys
{
    # This method is for dumping the contents of an array
    # Required:
    #   hash_ref   (array of values)
    # Return:
    #   string_ref  (data from array)
    my $self = shift;
    my $parameter = shift;
    my $sStringData = "";
    
    $sStringData .= "\t";
    foreach (keys(%$parameter))
    {
        $sStringData .= "$_, ";
    }
    $sStringData .= "\n";
    return \$sStringData;
}


return 1;
