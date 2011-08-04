#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Term::RouterCLI                                      #
# Class:       Hardware                                             #
# Description: Methods for building a Router (Stanford) style CLI   #
#                                                                   #
# Written by:  Bret Jordan (jordan at open1x littledot org)         #
# Created:     2011-04-27                                           #
##################################################################### 
#
#
#
#
package Term::RouterCLI::Hardware;

use 5.8.8;
use strict;
use warnings;

use parent qw(Exporter);
our @EXPORT      = qw();
our @EXPORT_OK   = qw();
our %EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );
our $VERSION     = '0.99_13';



sub new
{
    my $pkg = shift;
    my $class = ref($pkg) || $pkg;  

    my $self = {};
    $self->{_sName}                 = $pkg;        # Lets set the object name so we can use it in debugging
    $self->{_iDebug}                = 0;
    $self->{_oConfig}               = undef;       # Lets pull in the configuration file object so we can use it.
        
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

return 1;
