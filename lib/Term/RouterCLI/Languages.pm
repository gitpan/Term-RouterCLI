#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Term::RouterCLI                                      #
# Class:       Languages                                            #
# Description: Methods for building a Router (Stanford) style CLI   #
#                                                                   #
# Written by:  Bret Jordan (jordan at open1x littledot org)         #
# Created:     2011-02-21                                           #
##################################################################### 
#
#
#
#
package Term::RouterCLI::Languages;

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
    $self->{_oParent}           = undef;
    $self->{_hValidLanguages}   = { 'en_us' => 1, 'fr' => 1 };
    $self->{_sDirectoryTree}    = undef;
    $self->{_iDebugLang}        = 0;
        
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


sub GetLanguageDirectory
{
    # This method will return the current language directory as defined in the configuration file
    my $self = shift;
    
    unless (exists $self->{_oParent}->{_oConfig}->{_hConfigData}->{system}->{language_directory}) { return ('./lang/'); }
    return ($self->{_oParent}->{_oConfig}->{_hConfigData}->{system}->{language_directory});
}

sub AddValidLanguage
{
    # This method will add a valid language to lists
    # Required:
    #   hash_ref (valid languages where keys are ISO values)
    my $self = shift;
    my $hParameter = shift;
    print "--DEBUG Lang-- ### Entering AddValidLanguage ###\n" if ($self->{_iDebugLang} >= 1);

    foreach (keys (%$hParameter)) { $self->{_hValidLanguages}->{$_} = $hParameter->{$_}; }
    print "--DEBUG Lang-- ### Leaving AddValidLanguage ###\n" if ($self->{_iDebugLang} >= 1);
}

sub SetLanguage
{
    # This method will set the current language
    my $self = shift;
    my $lang = shift;
    
    if ($self->{_iDebugLang} >= 1)
    {
        print "--DEBUG Lang-- ### Entering SetLanguage ###\n";
        print "--DEBUG Lang-- lang: $lang\n";
        print "--DEBUG Lang-- _hValidLanguages: ";
        foreach (keys(%{$self->{_hValidLanguages}})) {print "$_, ";}
        print "\n";        
    }

    
    unless (defined $lang) { $lang = $self->{_oParent}->{_aCommandArguments}->[0]; }
    print "--DEBUG Lang-- recieved lang: $lang\n" if ($self->{_iDebugLang} >= 1);
    
    # If the language is not found for this parameter, then lets reset to US english
    unless (exists ($self->{_hValidLanguages}->{$lang})) { $lang = "en_us"; }
    print "--DEBUG Lang-- using lang: $lang\n" if ($self->{_iDebugLang} >= 1);
    
    $self->{_oParent}->{_oConfig}->{_hConfigData}->{language} = $lang;
    print "--DEBUG Lang-- ### Leaving SetLanguage ###\n" if ($self->{_iDebugLang} >= 1);
}

sub LoadStrings
{
    # This method is for loading all of the strings based on language from the configuration file
    # Required:
    #   string (name of directory that holds languages file for this command tree)
    # Return:
    #   hash_ref (hash of strings)
    my $self = shift;
    my $sTree = shift;
    
    # Lets add the directory tree to the object so we can use it again later with a reload strings method
    $self->{_sDirectoryTree} = $sTree;
    
    my $sLang;
    print "--DEBUG Lang-- ### Entering LoadStrings ###\n" if ($self->{_iDebugLang} >= 1);
    
    my $sBaseLangDir = $self->GetLanguageDirectory();
    if (exists $self->{_oParent}->{_oConfig}->{_hConfigData}->{language}) 
    { 
        $sLang = $self->{_oParent}->{_oConfig}->{_hConfigData}->{language}; 
        print "--DEBUG Lang-- Using language: $sLang\n" if ($self->{_iDebugLang} >= 1);
    }
    else 
    { 
        print "--DEBUG Lang-- Language not found, reverting to en_us\n" if ($self->{_iDebugLang} >= 1);
        $sLang = "en_us"; 
    }
    
    # If the language file does not yet exist, then lets return an empty hash
    unless (-r "$sBaseLangDir/$sTree/$sLang.lang") 
    {
        print "--DEBUG Lang-- Language file $sBaseLangDir/$sTree/$sLang.lang does not exist, returning\n" if ($self->{_iDebugLang} >= 1);
        return {};
    }
    
    my $sFullFilename = "$sBaseLangDir/$sTree/$sLang.lang";
    my $hLanguageSpecificStrings;

    print "--DEBUG Lang-- sFullFilename: $sFullFilename\n" if ($self->{_iDebugLang} >= 1); 
    
    if (-r $sFullFilename)
    {
        print "--DEBUG Lang-- Reading from file: $sFullFilename\n" if ($self->{_iDebugLang} >= 1);
        my $oStrings = new Config::General
        (
            -ConfigFile => "$sFullFilename",
            -LowerCaseNames => 1,
            -MergeDuplicateOptions => 1,
            -AutoTrue => 0,
            -ExtendedAccess => 1,
            -UTF8 => 1
        ); 
        # By using the getall function, we limit the IO calls to the configuration file and get all of the data at once
        my %hAllSavedStrings = $oStrings->getall();
        $hLanguageSpecificStrings = $hAllSavedStrings{$sLang};        
    }
    else { print "--DEBUG Lang-- Could not find file to read from\n" if ($self->{_iDebugLang} >= 1);}
    
    print "--DEBUG Lang-- ### Leaving LoadStrings ###\n" if ($self->{_iDebugLang} >= 1);
    return $hLanguageSpecificStrings;
}

sub ReloadStrings
{
    # This method is just a helper method for LoadStrings
    my $self = shift;
    $self->LoadStrings("$self->{_sDirectoryTree}");
}

return 1;
