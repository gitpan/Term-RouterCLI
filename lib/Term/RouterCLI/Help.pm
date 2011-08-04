#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Term::RouterCLI                                      #
# Class:       Help                                                 #
# Description: Methods for building a Router (Stanford) style CLI   #
#                                                                   #
# Written by:  Bret Jordan (jordan at open1x littledot org)         #
# Created:     2011-02-21                                           #
##################################################################### 
#
#
#
#
package Term::RouterCLI::Help;

use 5.8.8;
use strict;
use warnings;

use parent qw(Exporter);
our @EXPORT      = qw();
our @EXPORT_OK   = qw( PrintHelp _GetCommandHelp _GetCommandSummaries _GetCommandSummary);
our %EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );
our $VERSION     = '0.99_13';



# ----------------------------------------
# Public Methods 
# ----------------------------------------

sub PrintHelp
{
    # This method will print out a short description or long description depending on whether 
    # or not an argument "topic" is passed in.  If there is a command argument, then we will
    # print the detailed help topics.
    # Required:
    #   array_ref ($self->{_aCommandArguments})
    my $self = shift;
    my $OUT = $self->{OUT};

    print "--DEBUG PrintHelp 0-- ### Entering PrintHelp ###\n" if ($self->{_iDebugHelp} >= 1);

    # If there is an argument passed to the help function, then lets process those arguments 
    # finding the corresponding command and its help directives.  If there is no argument
    # passed in, then we will just print out all of the help summaries
    my $iNumberOfArguments =  @{$self->{_aCommandArguments}};
    print "--DEBUG PrintHelp 1-- iNumberOfArguments: $iNumberOfArguments\n" if ($self->{_iDebugHelp} >= 1);
    if ($iNumberOfArguments > 0) 
    {
        print "--DEBUG PrintHelp 2-- Step 2\n" if ($self->{_iDebugHelp} >= 1);
        my $sHelpAboutACommand = $self->_GetCommandHelp();
        print "--DEBUG PrintHelp 2-- sHelpAboutACommand: $$sHelpAboutACommand\n" if ($self->{_iDebugHelp} >= 1);

        print $OUT $$sHelpAboutACommand;
        print $OUT "\n";
    } 
    else 
    {
        print "--DEBUG PrintHelp 3-- Step 3\n" if ($self->{_iDebugHelp} >= 1);
        unless (exists($self->{_hCommandDirectives}->{cmds})) {$self->{_hCommandTreeAtLevel} = $self->GetFullCommandTree();}
        print $OUT $self->_GetCommandSummaries();
    }
    print "--DEBUG PrintHelp 0-- ### Leaving PrintHelp ###\n" if ($self->{_iDebugHelp} >= 1);
}


# ----------------------------------------
# Private Methods 
# ----------------------------------------

sub _GetCommandHelp
{
    # This method will get the command details from the help directive 
    # Required:
    #   hash_ref ($self->{_hCommandTreeAtLevel})   
    #   hash_ref ($self->{_hCommandDirectives})
    # Return:
    #   string_ref(help details for the command in question)
    my $self = shift;
    my $sHelpDetails = "";

    print "--DEBUG _GetCommandHelp 0-- ### Entering _GetCommandHelp ###\n" if ($self->{_iDebugHelp} >= 1);
    # Lets get the current data for the tree location that we are now at
    $self->_FindCommandInCommandTree(); 

    # If their are no command directives then lets look for a default command
    if (!$self->{_hCommandDirectives}) 
    {
        print "--DEBUG _GetCommandHelp 1-- Step 1\n" if ($self->{_iDebugHelp} >= 1);
        if (exists $self->{_hCommandTreeAtLevel}->{''}) { $self->{_hCommandDirectives} = $self->{_hCommandTreeAtLevel}->{''}; } 
        else 
        { 
            my ($sCommandName) = $self->_GetFullCommandName();
            $sHelpDetails = "$sCommandName doesn't exist.\n"; 
        }
    }
    else
    {
        print "--DEBUG _GetCommandHelp 2-- Step 2\n" if ($self->{_iDebugHelp} >= 1);
        if ($self->{display_summary_in_help}) 
        {
            my ($sCommand) = $self->_GetFullCommandName();
            if ($self->{_iDebugHelp} >= 1)
            {
                print "--DEBUG _GetCommandHelp 2-- Step 2.1\n";
                print "--DEBUG _GetCommandHelp 2-- sCommand: $sCommand\n";
            }
            # We need to take in to account if the desc or help is not in the translated lanugage pack
            if (exists($self->{_hCommandDirectives}->{desc}) && (defined $self->{_hCommandDirectives}->{desc})) 
            {
                $sHelpDetails = "$sCommand: " . $self->{_hCommandDirectives}->{desc} . "\n"; 
            } 
            else { $sHelpDetails = "$sCommand: Command description not found\n"; }
        }
        
        if (exists($self->{_hCommandDirectives}->{help}) && (defined $self->{_hCommandDirectives}->{help})) 
        { 
            $sHelpDetails .= $self->{_hCommandDirectives}->{help}; 
            $sHelpDetails .= "\n";
        } 
        else { $sHelpDetails = "No additional help found\n"; }

        if ($self->{display_subcommands_in_help} && exists($self->{_hCommandDirectives}->{cmds})) 
        { 
            $sHelpDetails .= "\nSubcommands available:\n";
            $sHelpDetails .= $self->_GetCommandSummaries(); 
        }
    }
    print "--DEBUG _GetCommandHelp 0-- ### Leaving _GetCommandHelp ###\n" if ($self->{_iDebugHelp} >= 1);
    return \$sHelpDetails;
}

sub _GetCommandSummaries
{
    # This method will return the command summaries for all commands at the current level of a command tree
    # Required:
    #   hash_ref ($self->{_hCommandTreeAtLevel}) 
    # Optional:
    #   array_ref (commands)
    my $self = shift;
    my $aCommands = shift;

    print "--DEBUG AllSummaries 0-- ### Entering _GetCommandSummaries ###\n" if ($self->{_iDebugHelp} >= 1);
    
    # This was added to support "?" mark tab completion when there is nothing yet entered on the command prompt
    unless (exists $aCommands->[0]) 
    {
        unless ( defined $self->{_hCommandTreeAtLevel} ) { $self->{_hCommandTreeAtLevel} = $self->GetCurrentCommandTree(); }
        foreach (sort(keys(%{$self->{_hCommandTreeAtLevel}})))
        {
            push @$aCommands, $_;
        }
    }

    if ($self->{_iDebugHelp} >= 1) 
    {     
        print "--DEBUG AllSummaries 1-- _hCommandTreeAtLevel: ";
        foreach (keys(%{$self->{_hCommandTreeAtLevel}})) {print "$_, ";}
        print "\n";     
        print "--DEBUG AllSummaries 1-- aCommands: ";
        foreach (@$aCommands) {print "$_, ";}
        print "\n";   
    }

    my $sAllCommandSummaries = "";

    # We need to push values in to this string for the following use cases:
    # 1) There is a code directive found on the command, meaning it can be ran by itself
    #    ()example "show interface" and "show interface brief")
    # 2) An actual argument is possible, we should print out some helper text so that the user will know what
    #    they should be entering
    
    if ( exists $self->{_hCommandDirectives}->{maxargs} && $self->{_hCommandDirectives}->{maxargs} >= 1 ) 
    {
        my $sArgDescription = "unknown";
        if (exists $self->{_hCommandDirectives}->{argdesc} && defined $self->{_hCommandDirectives}->{argdesc}) { $sArgDescription = $self->{_hCommandDirectives}->{argdesc}; } 
        $sAllCommandSummaries .= sprintf("  %-20s $sArgDescription\n", "WORD"); 
    }
    
    foreach (sort(@$aCommands)) 
    {
        # We now exclude synonyms from the command summaries.
        next if exists $self->{_hCommandTreeAtLevel}->{$_}->{alias} || exists $self->{_hCommandTreeAtLevel}->{$_}->{syn};
        # Lets not show the default command in any summaries
        next if $_ eq '';
        # Lets not show "hidden" options in any summaries
        next if exists $self->{_hCommandTreeAtLevel}->{$_}->{hidden};

        $sAllCommandSummaries .= $self->_GetCommandSummary("$_");
    }
    if ( exists $self->{_hCommandDirectives}->{code} ) { $sAllCommandSummaries .= sprintf("  %-20s\n", "<cr>"); }

    print "--DEBUG AllSummaries 0-- ### Leaving _GetCommandSummaries ###\n" if ($self->{_iDebugHelp} >= 1);
    return $sAllCommandSummaries;
}

sub _GetCommandSummary
{
    # This method returns the command summary for a specific command at a certain command tree level
    # Required:
    #   hash_ref ($self->{_hCommandTreeAtLevel})
    #   string (command name)
    # Return:
    #   string (command summary line)
    my $self = shift;
    my $sCommandName = shift;
    my $sCommandSummary;

    print "--DEBUG Summary 0-- ### Entering _GetCommandSummary ###\n" if ($self->{_iDebugHelp} >= 2);

    $sCommandSummary = $self->{_hCommandTreeAtLevel}->{$sCommandName}->{desc} || "(no description)";
    
    print "--DEBUG6.0-- ### Leaving _GetCommandSummary ###\n" if ($self->{_iDebugCompletion} >= 6);
    return sprintf("  %-20s $sCommandSummary\n", $sCommandName);
}

return 1;
