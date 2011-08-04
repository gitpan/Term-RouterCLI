#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Term::RouterCLI                                      #
# Class:       Auth                                                 #
# Description: Methods for building a Router (Stanford) style CLI   #
#                                                                   #
# Written by:  Bret Jordan (jordan at open1x littledot org)         #
# Created:     2011-04-27                                           #
##################################################################### 
#
#
#
#
package Term::RouterCLI::Auth;

use 5.8.8;
use strict;
use warnings;

use parent qw(Exporter);
our @EXPORT      = qw();
our @EXPORT_OK   = qw();
our %EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );
our $VERSION     = '0.99_13';

use Term::ReadKey;
use Digest::SHA qw(hmac_sha512_hex);


sub new
{
    my $pkg = shift;
    my $class = ref($pkg) || $pkg;  

    my $self = {};
    $self->{_sName}                 = $pkg;        # Lets set the object name so we can use it in debugging
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

sub PromptForUsername
{
    # This method will prompt for the username to be entered on the command line
    # Return:
    # string_ref (password entered)
    my $self = shift;
    my $sUsername = "";
    
    while(ord(my $key = ReadKey(0)) != 10) 
    {
        # This will continue until the Enter key is pressed (decimal value of 10)
        # For all value of ord($key) see http://www.asciitable.com/
        if (ord($key) == 127 || ord($key) == 8) 
        {
            # DEL/Backspace was pressed
            # Lets not allow backspace or del if there is not password characters to delete
            unless ($sUsername eq "")
            { 
                #1. Remove the last char from the password
                chop($sUsername);
                #2 move the cursor back by one, print a blank character, move the cursor back by one 
                print "\b \b";
            }
        }
        elsif (ord($key) <= 32 || ord($key) > 127) 
        { 
            # Do nothing with these control characters 
        }

        else { $sUsername = $sUsername.$key; }
    }
    return \$sUsername;
}

sub PromptForPassword
{
    # This method will prompt for the password to be entered on the command line
    # Return:
    # string_ref (password entered)
    my $self = shift;
    my $sPassword = "";
        
    # The following will hide all typeing, the while statement below will print * characters
    ReadMode(4);
    while(ord(my $key = ReadKey(0)) != 10) 
    {
        # This will continue until the Enter key is pressed (decimal value of 10)
        # For all value of ord($key) see http://www.asciitable.com/
        if (ord($key) == 127 || ord($key) == 8) 
        {
            # DEL/Backspace was pressed
            # Lets not allow backspace or del if there is not password characters to delete
            unless ($sPassword eq "")
            { 
                #1. Remove the last char from the password
                chop($sPassword);
                #2 move the cursor back by one, print a blank character, move the cursor back by one 
                print "\b \b";
            }
        }
        elsif (ord($key) <= 32 || ord($key) > 127) 
        { 
            # Do nothing with these control characters 
        }

        else 
        {
            $sPassword = $sPassword.$key;
            print "*";
        }
    }
    # Reset the terminal 
    ReadMode(0);
    # Since the Term::ReadKey method above strips out the carriage return, lets add it back
    print "\n";

    return \$sPassword;
}

sub EncryptPassword
{
    # This method will encrypt a password with some salt
    # Required:
    #   int_ref    (type)
    #   string_ref (password)
    #   string_ref (salt)
    # Return:
    #   string_ref (encrypted password)
    my $self = shift;
    my $iCryptIDType = shift;
    my $sPassword = shift;
    my $sSalt = shift;
    my $sCryptPassword = "";

    print "--DEBUG $self->{_sName} 0-- ### Entering EncryptPassword ###\n" if ($self->{_iDebug} >= 1);
     
    # If Crypt ID Type == 0, then there is no encryption
    if    ( $$iCryptIDType == 0 && defined $$sPassword) { $sCryptPassword = $$sPassword; }
    elsif ( $$iCryptIDType == 6 && defined $$sPassword && defined $$sSalt) { $sCryptPassword = hmac_sha512_hex($$sPassword, $$sSalt); }

    print "--DEBUG $self->{_sName} 0-- ### Leaving EncryptPassword ###\n" if ($self->{_iDebug} >= 1);
    return \$sCryptPassword;
}

sub SplitPasswordString
{
    # This method will split a password string of $id$salt$password in to the relevant parts
    # Required
    #   string_ref (password string)
    # Return:
    #   int_ref    (crypt id)
    #   string_ref (salt)
    #   string_ref (password)
    my $self = shift;
    my $sPasswordString = shift;
    my $iID;
    my $sSalt = "";
    my $sPassword = "";

    print "--DEBUG $self->{_sName} 0-- ### Entering SplitPasswordString ###\n" if ($self->{_iDebug} >= 1);
    print "--DEBUG $self->{_sName} 1-- sPasswordString: $$sPasswordString\n" if ($self->{_iDebug} >= 3);    

    # Split key from password
    ($iID, $sSalt, $sPassword) = (split /\$/, $$sPasswordString)[1..3];
    
    if ($self->{_iDebug} >= 3)
    {
        print "--DEBUG $self->{_sName} 1-- iID: $iID\n";
        print "--DEBUG $self->{_sName} 1-- sSalt: $sSalt\n";
        print "--DEBUG $self->{_sName} 1-- sPassword: $sPassword\n";
    }
    print "--DEBUG $self->{_sName} 0-- ### Leaving SplitPasswordString ###\n" if ($self->{_iDebug} >= 1);
    return (\$iID, \$sSalt, \$sPassword);
}



return 1;
