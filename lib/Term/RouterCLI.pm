#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Term                                                 #
# Class:       RouterCLI                                            #
# Description: Methods for building a Router (Stanford) style CLI   #
#                                                                   #
# This class is a fork and major rewrite of Term::ShellUI v0.98     #
# which was written by Scott Bronson.                               #
#                                                                   #
# Written by:  Bret Jordan (jordan at open1x littledot org)         #
# Created:     2011-02-21                                           #
##################################################################### 
#
#
#
#
package Term::RouterCLI;

use 5.8.8;
use strict;
use warnings;

use parent qw(Exporter);
our @EXPORT      = qw();
our @EXPORT_OK   = qw();
our %EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );
our $VERSION     = '0.99_13';
$VERSION = eval $VERSION;

use Term::RouterCLI::Auth;
use Term::RouterCLI::Log::History;
use Term::RouterCLI::Log::Audit;
use Term::RouterCLI::Config;
use Term::RouterCLI::CommandTree qw(:all);
use Term::RouterCLI::Help qw(:all);
use Term::RouterCLI::Prompt qw(:all);

use Term::ReadLine();
use Text::Shellwords::Cursor;
use Config::General;
use Sys::Syslog qw(:DEFAULT setlogsock);
use POSIX qw(strftime);
use Env qw(SSH_TTY);

sub new
{
    my $pkg = shift;
    my $class = ref($pkg) || $pkg;  
    
    my $self = {};
    $self->{_sName}                 = $pkg;        # Lets set the object name so we can use it in debugging
    
    # Objects
    $self->{_oAuditLog}                         = undef;
    $self->{_oConfig}                           = undef;
    $self->{_oHistory}                          = undef;
    $self->{_oTerm}                             = undef;
    
    # Application data
    $self->{_sConfigFilename}                   = './etc/RouterCLI.conf';
    $self->{_sCurrentPrompt}                    = "Router> ";
    $self->{_sCurrentPromptLevel}               = '> ';
    $self->{_sActiveLoggedOnUser}               = "";
    $self->{_sTTYInUse}                         = "localhost";
    $self->{_iExit}                             = 0;
    $self->{OUT}                                = undef;

    # Data structure
    $self->{_hFullCommandTree}                  = undef;    # Full command tree for active session
    $self->{_hCommandTreeAtLevel}               = undef;    # Command tree at current level for searching for a command
    $self->{_hCommandDirectives}                = undef;    # Directives of command found at deepest level
    $self->{_aFullCommandName}                  = undef;    # Full name of deepest command
    $self->{_aCommandArguments}                 = undef;    # All remaining arguments once command is determined

    # Data structure helper values
    $self->{_sStringToComplete}                 = "";       # The exact string that needs to be tab completed
    $self->{_sCompleteRawline}                  = "";       # Pre-tokenized command line
    $self->{_iStringToCompleteTextStartPosition} = 0;       # Position in _sCompleteRawline of the start of _sStringToComplete
    $self->{_iCurrentCursorLocation}            = 0;        # Position in _sCompleteRawline of the cursor (end of _sStringToComplete)
    $self->{_aCommandTokens}                    = undef;    # Tokenized command-line
    $self->{_iTokenNumber}                      = 0;        # The index of the token containing the cursor
    $self->{_iTokenOffset}                      = 0;        # the character offset of the cursor in $tokno.
    $self->{_iArgumentNumber}                   = 0;        # The argument number containing the cursor
    $self->{_iNumberOfContinuedLines}           = 0;        # The number of lines that have been entered in wrapped line continue mode

    $self->{_sPreviousCommand}                  = ""; 
    
   
    # Options
    $self->{blank_repeats_cmd}                  = 0;
    $self->{backslash_continues_command}        = 1;        # This allows commands to be entered across multiple lines
    $self->{display_summary_in_help}            = 1;
    $self->{display_subcommands_in_help}        = 1;
    $self->{suppress_completion_escape}         = 0;

    # Debug Options
    $self->{_iDebugCompletion}                  = 0;
    $self->{_iDebugFind}                        = 0;
    $self->{_iDebugHelp}                        = 0;        # 1 = _GetCommandSummaries, 2 = 1 + _GetCommandSummary
    $self->{_iDebugAuth}                        = 0; 
    $self->{_iDebug}                            = 0;
    
    # Text::Shellwords::Cursor module options
    $self->{_oParser}                           = undef;
    $self->{_sTokenCharacters}                  = '';
    $self->{_iKeepQuotes}                       = 1;
    
    # Lets overwrite any defaults with values that are passed in
    my %hParameters = @_;
    foreach (keys (%hParameters)) { $self->{$_} = $hParameters{$_}; }

    bless ($self, $class); 

    # Create sub objects
    $self->{_oHistory}  = new Term::RouterCLI::Log::History( _oParent => $self, _sFilename => './logs/.cli-history', _iDebug => 0  );
    $self->{_oAuditLog} = new Term::RouterCLI::Log::Audit(   _oParent => $self, _sFilename => './logs/.cli-auditlog', _iDebug => 0 );
        
    $self->{_oParser} = Text::Shellwords::Cursor->new(
        token_chars => $self->{_sTokenCharacters},
        keep_quotes => $self->{_iKeepQuotes},
        debug => 0,
        error => sub { shift; $self->error(@_); },
        );

    # Create object for terminal and define some initial values
    $self->{_oTerm} = new Term::ReadLine("$0");
    $self->{_oTerm}->MinLine(0);
    $self->{_oTerm}->parse_and_bind("\"?\": complete");
    $self->{_oTerm}->Attribs->{completion_function} = sub { _CompletionFunction($self, @_); };
    $self->SetOutput("term");

    # Lets capture the tty that they used to connected to the CLI
    if (defined $SSH_TTY) { $self->{_sTTYInUse} = $SSH_TTY; }

    return $self;
}

sub DESTROY
{
    my $self = shift;
    $self = {};
}

sub RESET
{
    # This method will reset the data structure
    my $self = shift;
    # Data structure
    $self->{_hCommandTreeAtLevel}               = undef;
    $self->{_hCommandDirectives}                = undef;
    $self->{_aFullCommandName}                  = undef;
    $self->{_aCommandArguments}                 = undef;
    # Helper values
    $self->{_sStringToComplete}                 = "";    
    $self->{_sCompleteRawline}                  = "";
    $self->{_iStringToCompleteTextStartPosition} = 0;
    $self->{_iCurrentCursorLocation}            = 0;
    $self->{_aCommandTokens}                    = undef;
    $self->{_iTokenNumber}                      = 0;
    $self->{_iTokenOffset}                      = 0;
    $self->{_iArgumentNumber}                   = 0;
    $self->{_iNumberOfContinuedLines}           = 0;
}


# ----------------------------------------
# Public Convenience Functions
# ----------------------------------------
sub EnableAuditLog          { shift->{_oAuditLog}->Enable();            }
sub DisableAuditLog         { shift->{_oAuditLog}->Disable();           }
sub SetAuditLogFilename     { shift->{_oAuditLog}->SetFilename(@_);     }
sub SetAuditLogFileLength   { shift->{_oAuditLog}->SetFileLength(@_);   }

sub EnableHistory           { shift->{_oHistory}->Enable();             }
sub DisableHistory          { shift->{_oHistory}->Disable();            }
sub SetHistoryFilename      { shift->{_oHistory}->SetFilename(@_);      }
sub SetHistoryFileLength    { shift->{_oHistory}->SetFileLength(@_);    }
sub PrintHistory            { shift->{_oHistory}->PrintHistory(@_);     }



# ----------------------------------------
# Public Functions
# ----------------------------------------
sub SetConfigFilename
{
    # This method will set the configuration file name
    # Required:
    #   hash_string (filename including path ex ./etc/RouterCLI.conf)
    my $self = shift;
    my $sFilename = shift;
    if (defined $sFilename) { $self->{_sConfigFilename} = $sFilename }
}

sub LoadConfig
{
    # This method will load the current configuration in to memory
    # Return:
    #   hash_ref (configuration data)
    my $self = shift;
    
    $self->{_oConfig} = new Term::RouterCLI::Config( _sFilename => $self->{_sConfigFilename} );
    $self->{_oConfig}->LoadConfig();
}

sub SaveConfig
{
    # This method will save the current configuration out to a text file
    my $self = shift;
    $self->{_oConfig}->SaveConfig();
}

sub ClearScreen
{
    # This function will clear the screen from all login information
    my $self = shift;
    print `clear`;
}

sub PrintMOTD
{
    # This function will print out a welcome message
    my $self = shift;
    print "\n\n$self->{_oConfig}->{_hConfigData}->{motd}->{text}\n";
}

sub SetHostname
{
    # This method will set the hostname
    my $self = shift;
    my $parameter = shift;
    unless (defined $parameter) { $parameter = $self->{_aCommandArguments}->[0]; }
    $self->{_oConfig}->{_hConfigData}->{hostname} = $parameter;
    # When ever the hostname is changes, we need to refresh the prompt
    $self->SetPrompt($parameter);
}

sub SetLangDirectory
{
    # this method will change the language directory field in the configuration data hash
    # Required:
    #   string (directory path, full or relative)
    my $self = shift;
    my $parameter = shift;
    if ($self->{_iDebug} > 0)
    {
        print "DEBUG SetLangDir: Entering SetLangDirectory\n";
        print "DEBUG SetLangDir: Current Language Directory is: $self->{_oConfig}->{_hConfigData}->{system}->{language_directory}\n";
        print "DEBUG SetLangDir: New Language Directory is: $parameter\n";
    }
    unless (defined $parameter) { return; }
    $parameter = $self->_ExpandTildes($parameter);
    $self->{_oConfig}->{_hConfigData}->{system}->{language_directory} = $parameter;
    if ($self->{_iDebug} > 1)
    {
        print "DEBUG SetLangDir: Directory is now: $self->{_oConfig}->{_hConfigData}->{system}->{language_directory}\n";
        print "DEBUG SetLangDir: Leaving SetLangDirectory\n";
    }

}

sub StartCLI
{
    # This method will start the actual processing of the CLI
    my $self = shift;
    
    $self->{_oAuditLog}->StartAuditLog() if ($self->{_oAuditLog}->{_bEnabled} == 1 );
    
    unless (defined $self->{_hFullCommandTree}) { die "Please load an initial command tree\n"; }
    
    # Set prompt from configuration file
    $self->ClearPromptOrnaments();
    $self->SetPrompt($self->{_oConfig}->{_hConfigData}->{hostname});
    
    
    # Load the previous command history in to memory
    $self->{_oHistory}->LoadCommandHistoryFromFile() if ($self->{_oHistory}->{_bEnabled} == 1 );

    while($self->{_iExit} == 0) 
    {
        $self->_ProcessCommands();
    }
       
    # Close AuditLog and save command History
    $self->{_oHistory}->SaveCommandHistoryToFile() if ($self->{_oHistory}->{_bEnabled} == 1 );
    $self->{_oHistory}->CloseFileHandle();
    $self->{_oAuditLog}->CloseFileHandle();
}

sub SetOutput
{
    # This method will define where the output goes
    # Required:
    #   string (term/stdout)
    my $self = shift;
    my $parameter = shift || "";
    if ($parameter eq "term") {$self->{OUT} = $self->{_oTerm}->OUT || \*STDOUT;}
    else { $self->{OUT} = \*STDOUT; }
}

sub Exit 
{ 
    # This method will cause the CLI to exit
    shift->{_iExit} = 1; 
}

sub PreventEscape
{
    # This method will capture the various signals and prevent termination and esacpe through control characters
    # Turn off the following CTRLs
    my $self = shift;
    $self->{_oTerm}->Attribs->{'catch_signals'} = 0;
    system("stty eof \"?\"");    # CTRL-D
    $SIG{"INT"}  = 'IGNORE';     # CTRL-C
    $SIG{"TSTP"} = 'IGNORE';     # CTRL-Z
    $SIG{"QUIT"} = 'IGNORE';     # CTRL-\
    $SIG{"TERM"} = 'IGNORE';
    $SIG{"ABRT"} = 'IGNORE';
    $SIG{"SEGV"} = 'IGNORE';
    $SIG{"ILL"} = 'IGNORE';
}

sub TabCompleteArguments
{
    # This method will provide tab completion for the "help" arguments and "no" arguments
    # Required:
    #   hash_ref (full data structure)
    my $self = shift;

    # Lets backup the data structure before we run the _CompleteFunction again
    my $sStringToCompleteBackup = $self->{_sStringToComplete};
    my $sCompleteRawlineBackup = $self->{_sCompleteRawline};
    my $aFullCommandNameBackup = $self->{_aFullCommandName};
    my $hCommandTreeAtLevelBackup = $self->{_hCommandTreeAtLevel};
    my $hCommandDirectivesBackup = $self->{_hCommandDirectives};
    
    my ($sArgsToComplete) = $self->_GetFullArgumentsName();
    $self->_CompletionFunction("NONE", $sArgsToComplete) unless ($sArgsToComplete eq "");

    # Lets grab what came back, which is really arguments, and put it in the arguments array
    $self->{_aCommandArguments} = $self->{_aFullCommandName};
    
    # Lets now restore the command name from the beginning along with the command directives
    $self->{_sStringToComplete} = $sStringToCompleteBackup;
    $self->{_sCompleteRawline} = $sCompleteRawlineBackup;
    $self->{_aFullCommandName} = $aFullCommandNameBackup;
    $self->{_hCommandTreeAtLevel} = $hCommandTreeAtLevelBackup;
    $self->{_hCommandDirectives} = $hCommandDirectivesBackup;

    # TODO look at this and see if I need it
    # without this we'd complete with $shCommandTreeAtLevel for all further args
    #return [] if $self->{_iArgumentNumber} >= @{$self->{_aFullCommandName}};
}

sub error
{
    my $self = shift;
    print STDERR @_;
}





# ----------------------------------------
# Private Methods 
# ----------------------------------------
sub _ExpandTildes
{
    # This method will expand any tildes that are in the file name so that it will work right
    # Required:
    #   string (directory to be expanded)
    my $self = shift;
    my $parameter = shift;
    
    $parameter =~ s/^~([^\/]*)/$1?(getpwnam($1))[7]:$ENV{HOME}||$ENV{LOGDIR}||(getpwuid($>))[7]/e;
    return $parameter;
}

sub _ProcessCommands
{
    # This method prompts for and returns the results from a single command. Returns undef if no command was called.
    my $self = shift;

    # Before we get started, lets clear out the data structure from the last command we processed
    $self->RESET();    

    my $iSaveToHistory = 1;
    my $sPrompt;

    my $OUT = $self->{'OUT'};

	
	# Setup an infinte loop to catch all of the commands entered on the console makeing sure
	# to watch for "\" continue to next line characters
	for(;;) 
	{
		$sPrompt = $self->GetPrompt();

        # This next command is where we jump to the _CompletionFunction method and it does not come
        # back to this fucntion until the enter key is pressed
        # TODO we need to make sure the readline is returning a valid option with "?" is pressed
		my $sNewline = $self->{_oTerm}->readline($sPrompt);
        print "--DEBUG ProcessCommands-- Newline returned from readline: $sNewline\n" if ($self->{_iDebug} >= 1 && defined $sNewline);

        # In the off chance that the readline module does not return anything, lets just print a new line and go on.
        unless (defined $sNewline) 
        {
            if (!exists $self->{_aFullCommandName}->[0] || $self->{_aFullCommandName}->[0] eq "")
            {
                # Print out possible options for the matches that were found. This was added once 
                # "?" based completion was added
                print $OUT "\n";
                print $OUT $self->_GetCommandSummaries();
    
                # We need to redraw the prompt and command line options since we are going to output text via _GetCommandSummaries
                $self->{_oTerm}->rl_on_new_line();
                return;            
            }
            else 
            {
                print $OUT "\n";
                $self->{_oTerm}->rl_on_new_line();
                return;
            }
        }

        # If there is any white space at the start or end of the command lets remove it just to be safe 
        $sNewline =~ s/^\s+//g;  
        $sNewline =~ s/\s+$//g;  



        # Search for a "\" at the end as a continue character and remove it along with any white space
        # if one was found lets set bContinued to TRUE so we know that we need more commands.  Lets
        # also keep track of the number of lines that are continued.  This makes the logic easier down
        # below.
        my $bContinued = 0;
        if ($self->{backslash_continues_command} == 1)
        {
            $bContinued = ($sNewline =~ s/\s*\\$/ /);
            if ($bContinued == 1) { $self->{_iNumberOfContinuedLines} = $self->{_iNumberOfContinuedLines} + $bContinued; }
        }
        
        if ($self->{_iDebug} >= 1)
        {
            print "--DEBUG ProcessCommands-- _iNumberOfContinuedLines: $self->{_iNumberOfContinuedLines}\n" ;  
            print "--DEBUG ProcessCommands-- bContinued: $bContinued\n";            
        }

        # Lets concatenate the lines together to form a single command
        if (($self->{backslash_continues_command} == 1) && ($self->{_iNumberOfContinuedLines} > 0))
        {
            $self->{_sCompleteRawline} = $self->{_sCompleteRawline} . $sNewline;
            if ($bContinued == 1) { next; }
        }
        else { $self->{_sCompleteRawline} = $sNewline; }

        # This will allow us to enter partial commands on the command line and have them completed
        print "--DEBUG ProcessCommands-- _sCompleteRawline: $self->{_sCompleteRawline}\n" if ($self->{_iDebug} >= 1);        
        $self->_CompletionFunction("NONE", $self->{_sCompleteRawline}) unless ($self->{_sCompleteRawline} eq ""); 
        last; 
	} 

    # Is this a blank line?  If so, then we might need to repeat the last command
    if ($self->{_sCompleteRawline} =~ /^\s*$/) 
    {
        if ($self->{blank_repeats_cmd} && $self->{_sPreviousCommand} ne "") 
        {
            $self->{_oTerm}->rl_forced_update_display();
            print $OUT $self->{_sPreviousCommand};
            $self->_CompletionFunction("NONE", $self->{_sPreviousCommand}); 
        }
        else { $self->{_sCompleteRawline} = undef; }
        return unless ((defined $self->{_sCompleteRawline}) && ($self->{_sCompleteRawline} !~ /^\s*$/));
    }

    my $sCommandString = undef;

    if (exists $self->{_aFullCommandName}) 
    {
        my ($sCommandName) = $self->_GetFullCommandName();
        my ($sCommandArgs) = $self->_GetFullArgumentsName();
        $sCommandString = $sCommandName . $sCommandArgs;

        $self->_RunCodeDirective();


        # TODO we need to make sure that sub commands can inherit the hidden flag from the parent
        # If the command has an exclude from history or hidden option attached to it, lets NOT record it in the history file
		if (exists $self->{_hCommandDirectives}->{exclude_from_history} || exists $self->{_hCommandDirectives}->{hidden}) 
		{
			$iSaveToHistory = 0;
		}
    }

    # Add to history unless it's a dupe of the previous command.
	if (($iSaveToHistory == 1) && ($sCommandString ne $self->{_sPreviousCommand}) && ($self->{_oHistory}->{_bEnabled} == 1 ))
	{
		$self->{_oTerm}->addhistory($sCommandString);
	}
    $self->{_sPreviousCommand} = $sCommandString;
    

    
    # Lets save the typed in command to the audit log if the audit log is enabled and after the 
    # commands have been tab completed
    if ($self->{_oAuditLog}->{_bEnabled} == 1) 
    {
        my $hAuditData = { "username" => $self->{_sActiveLoggedOnUser}, "tty" => $self->{_sTTYInUse}, "prompt" => $sPrompt, "commands" => $sCommandString};
        $self->{_oAuditLog}->RecordToLog($hAuditData); 
    }
    
    # TODO build a logger that all of this will go in to
    # TODO add support to send history to RADIUS in the form of RADIUS account records
    # TODO add support for sending history to syslog server
#    if (($iSaveToHistory == 1) && ($self->{_oConfig}->{_hConfig}->{syslog} == 1))
#    {
#        setlogsock('udp');
#        $Sys::Syslog::host = $self->{_oConfig}->{_hConfig}->{syslog_server};
#        my $sTimeStamp = strftime "%Y-%b-%e %a %H:%M:%S", localtime;
#        openlog("RouterCLI", 'ndelay', 'user');
#        syslog('info', "($sTimeStamp) \[$sPrompt\] $sCommandString");
#        closelog;
#    }

    return;
}

sub _GetFullCommandName
{
    # This method will take in an array reference of the commands and return a single string value and the 
    # length of the string as an array
    # Required:
    #   $self->{_aFullCommandName} array_ref (commands typed in on the CLI)
    # Return:
    #   string  (full command name)
    #   int     (length of command name)
    my $self = shift;
    my $sCommandName = join(" ", @{$self->{_aFullCommandName}});
    $sCommandName = $sCommandName . " ";
    $sCommandName =~ s/^\s+//g;
    my $iCommandLength = length($sCommandName);
    return ($sCommandName, $iCommandLength);
}

sub _GetFullArgumentsName
{
    # This method will take in an array reference of the command arguments and return a single string value
    # and the length of the string as an array
    # Required:
    #   $self->{_aCommandArguments} array_ref (command arguments typed in on the CLI)
    # Return:
    #   string  (full command argument name minus the space at the end as you want to leave the cursor at the end)
    #   int     (length of argument name)
    my $self = shift;
    my $sArgumentName = join(" ", @{$self->{_aCommandArguments}});
    $sArgumentName =~ s/^\s+//g;
    my $iArgumentNameLength = length($sArgumentName);
    return ($sArgumentName, $iArgumentNameLength);
}

sub _FindCommandInCommandTree
{
    # This method will attempt to looks up the supplied commands from the $self->{_aCommandTokens}
    # array_ref in the command tree hash.  It will follows all synonyms and subcommands in an effort 
    # to find the command that the user typed in.  After it finds all of the commands it can
    # find, it will store the remaining data in to the _aCommandArgument array.
    # Required:
    #   hash_ref    $self->{_hCommandTreeAtLevel} (command tree)
    #   array_ref   $self->{_aCommandTokens} (typed in commands/tokens) these have already been 
    #               split on whitespace by Text::Shellwords::Cursor
    #
    # Variables set in the object:
    #   _hCurrentCommandTreeAtLevel:    The deepest command tree set found.  Always returned.
    #   _hCommandDirectives:            The command directives hash for the command.  Sets an empty hash if 
    #                                   no command was found.
    #   _aFullCommandName:              The full name of the command.  This is an array of tokens,
    #                                   i.e. ('show', 'info').  Returns as deep as it could find commands.  
    #   _aCommandArguments:             The command's arguments (all remaining tokens after the command is found).

    my $self = shift;
   
    my $aCommandTokens      = $self->{_aCommandTokens};
    my $hCommandTree        = $self->GetFullCommandTree();
    my $hCommandDirectives  = undef;
    my $iCurrentToken       = 0;
    my $iNumberOfTokens     = @$aCommandTokens;
    my @aFullCommandName;
    my @aCommandArguments;

    if ($self->{_iDebugFind} >= 1)
    {
        print "\n";
        print "--DEBUG FIND 0-- ### Entering _FindCommandInCommandTree ###\n";
        print "--DEBUG FIND 0-- Initial variable values\n";
        print "--DEBUG FIND 0-- \thCommandTree: ";
        foreach (keys(%$hCommandTree)) { print "$_, "; }
        print "\n";
        print "--DEBUG FIND 0-- \taCommandTokens: ";
        foreach (@$aCommandTokens) { print "$_, "; }
        print "\n";
        print "--DEBUG FIND 0-- \tiCurrentToken: $iCurrentToken\n"; 
        print "--DEBUG FIND 0-- \tiNumberOfTokens: $iNumberOfTokens\n"; 
    }

    foreach my $sToken (@$aCommandTokens)
    {
        # If the user has already gone beyond the number of args, then lets not complete and lets return 
        # an empty array so that things stop
        # TODO write a unit test for this and we need to figure out how to track if the show has a maxargs of 3 but
        # int does not a maxargs entry.
#        my $iMaxArgCheck = 0;
#        my $iCurrentTokenInMaxArgCheck = $iCurrentToken;
#        foreach (@$aCommandTokens)
#        {
#            $iMaxArgCheck = 1 if ((exists($self->{hCommandTree}->{$_}->{maxargs})) && ($iCurrentTokenInMaxArgCheck >= $self->{hCommandTree}->{$_}->{maxargs}));
#            $iCurrentTokenInMaxArgCheck--;
#        }
#        print "--DEBUG FIND 1-- Maximum argument limit reached for token: $sToken\n" if ($self->{_iDebugFind} >= 1 && $iMaxArgCheck == 1);
#        last if ($iMaxArgCheck == 1);


        print "--DEBUG FIND 1-- Working with token ($iCurrentToken): $sToken\n" if ($self->{_iDebugFind} >= 1);
        
        # If the token is NOT currently found then it might be a partial command or an abbreviation
        # so let try and expand the token if we can with what we know.  
        my @aCommandsAtThisLevel;
        my $iNumberOfCommandMatches = 0;
        if (!exists $hCommandTree->{$sToken})
        {
            @aCommandsAtThisLevel = keys(%$hCommandTree);
           
            if ($self->{_iDebugFind} >= 1)
            {
                print "--DEBUG FIND 2-- aCommandsAtThisLevel: ";
                foreach (@aCommandsAtThisLevel) { print "$_, "; }
                print "\n";                
            }
            @aCommandsAtThisLevel = grep {/^$sToken/} @aCommandsAtThisLevel;
            if ($self->{_iDebugFind} >= 1)
            {
                print "--DEBUG FIND 2-- aCommandsAtThisLevel: ";
                foreach (@aCommandsAtThisLevel) { print "$_, "; }
                print "\n";                
            }          
            # If there is only one option in the array, then it must be the right one.  If not
            # then we have an ambiguous command situation.  Also we need to make sure that the
            # command is not set be excluded from completion or flagged as hidden.
            $iNumberOfCommandMatches = @aCommandsAtThisLevel;
            print "--DEBUG FIND 2-- iNumberOfCommandMatches: $iNumberOfCommandMatches\n" if ($self->{_iDebugFind} >= 1);
            if (($iNumberOfCommandMatches == 1) && (!exists ($hCommandTree->{$aCommandsAtThisLevel[0]}->{exclude_from_completion})) && (!exists ($hCommandTree->{$aCommandsAtThisLevel[0]}->{hidden}))) 
            {
                print "--DEBUG FIND 2-- Setting sToken to $aCommandsAtThisLevel[0]\n" if ($self->{_iDebugFind} >= 1); 
                $sToken = $aCommandsAtThisLevel[0]; 
            }
        }
        
        # Lets loop through all synonyms to find the actual command and then update the token
        while (exists($hCommandTree->{$sToken}) && exists($hCommandTree->{$sToken}->{'alias'})) 
        {
            print "--DEBUG FIND 3-- Checking aliases\n" if ($self->{_iDebugFind} >= 1);
            $sToken = $hCommandTree->{$sToken}->{'alias'};
        }
        
        # If the command exists we need to capture the current directives for it and we need to add
        # the command to the aFullCommandName array.  If it does not exist, then we should put the 
        # remaining arguments in the aCommandArgument array and return.  This first one will also
        # match a blank line entered if a default command is enabled.  So we need to watch for that
        # when the rest of the default commands will match in the else statement below.
        if (exists $hCommandTree->{$sToken} )
        {
            print "--DEBUG FIND 4-- Command $sToken found\n" if ($self->{_iDebugFind} >= 1);

            $hCommandDirectives = $hCommandTree->{$sToken};
            push(@aFullCommandName, $sToken);
            
            # We need to zero out the hCommandTree if their is no subcommands so that we do not get 
            # in to a state where we can continue completing the last command over and over again.
            # Example: 'sh'<TAB> 'hist'<TAB> 'hist'<TAB>
            if (exists($hCommandDirectives->{cmds})) { $hCommandTree   = $hCommandDirectives->{cmds}; }
            elsif ($sToken eq "") { }
            else { $hCommandTree   = {}; }
        }
        else 
        {
            # Lets check to see if the command is a default command.  Which means if they typed in 
            # something that was not found in the command list, then there should be no _hCommandDirectives.  
            # But we also need to make sure that a default command option was defined in the configuration file
            if (!defined $hCommandDirectives && exists $hCommandTree->{''} && $iNumberOfCommandMatches < 1) 
            {
                print "--DEBUG FIND 5-- Default command found\n" if ($self->{_iDebugFind} >= 1);
                $hCommandDirectives = $hCommandTree->{''};
                push(@aFullCommandName, $sToken);

                # Since we are using the active token as a command, a default command, then lets not include that
                # in the arguments.  Thus the +1
                foreach ($iCurrentToken+1..$iNumberOfTokens-1) 
                { 
                    print "--DEBUG FIND 5-- Command to be added to arguments array is $aCommandTokens->[$_]\n" if ($self->{_iDebugFind} >= 1);
                    unless ($aCommandTokens->[$_] eq "") { push(@aCommandArguments, $aCommandTokens->[$_]); } 
                }
                last;
            }
            else 
            {
                # We need to grab the remaining tokens, once a command is not found, and add them to the 
                # aCommandArguments array
                print "--DEBUG FIND 6-- Command $sToken NOT found\n" if ($self->{_iDebugFind} >= 1);
                foreach ($iCurrentToken..$iNumberOfTokens-1) 
                { 
                    print "--DEBUG FIND 6-- Command to be added to arguments array is $aCommandTokens->[$_]\n" if ($self->{_iDebugFind} >= 1);
                    unless ($aCommandTokens->[$_] eq "") { push(@aCommandArguments, $aCommandTokens->[$_]); } 
                }
                last;
            }

        }

        if ($self->{_iDebugFind} >= 1)
        {
            print "--DEBUG FIND 7-- Variables defined for iCurrentToken: $iCurrentToken\n";
            print "--DEBUG FIND 7-- \thCommandTree: ";
            foreach (keys(%$hCommandTree)) { print "$_, "; }
            print "\n";
            print "--DEBUG FIND 7-- \thCommandDirectives: ";
            if (defined $hCommandDirectives) 
            { 
                print "$hCommandDirectives "; 
                foreach (keys(%$hCommandDirectives)) { print "$_, "; }
            }
            else { print "NOT DEFINED "; }
            print "\n";
            print "--DEBUG FIND 7-- \taCommandTokens: ";
            foreach (@$aCommandTokens) { print "$_, "; }
            print "\n";
            print "--DEBUG FIND 7-- \taFullCommandName: ";
            foreach (@aFullCommandName) { print "$_, "; }
            print "\n";            
            print "--DEBUG FIND 7-- \taCommandArguments: ";
            foreach (@aCommandArguments) { print "$_, "; }    
            print "\n";
        }

        $iCurrentToken++;
    }
 
    $self->{_hCommandTreeAtLevel}   = $hCommandTree;
    $self->{_hCommandDirectives}    = $hCommandDirectives || {};
    $self->{_aFullCommandName}      = \@aFullCommandName;
    $self->{_aCommandArguments}     = \@aCommandArguments;

    # Escape the completions so they're valid on the command line
    # I am not sure if this is the right place yet for this to be done.  Need to write some unit
    # tests to verify
    $self->{_oParser}->parse_escape($self->{_aFullCommandName}) unless $self->{suppress_completion_escape};
    $self->{_oParser}->parse_escape($self->{_aCommandArguments}) unless $self->{suppress_completion_escape};
    
    if ($self->{_iDebugFind} >= 1) 
    {
        print "--DEBUG FIND 8-- Final variables set by _FindCommandInCommandTree function\n";
        print "--DEBUG FIND 8-- \t_hCommandTreeAtLevel: $self->{_hCommandTreeAtLevel}: ";
        foreach (keys(%{$self->{_hCommandTreeAtLevel}})) { print "$_, "; }
        print "\n";
        print "--DEBUG FIND 8-- \t_hCommandDirectives: $self->{_hCommandDirectives}: ";
        foreach (keys(%{$self->{_hCommandDirectives}})) { print "$_, "; }
        print "\n";
        print "--DEBUG FIND 8-- \t_aFullCommandName: $self->{_aFullCommandName}: ";
        foreach (@{$self->{_aFullCommandName}}) { print "$_, "; }
        print "\n";
        print "--DEBUG FIND 8-- \t_aCommandArguments: $self->{_aCommandArguments}: ";
        foreach (@{$self->{_aCommandArguments}}) { print "$_, "; }    
        print "\n";
    }

    print "--DEBUG FIND 0-- ### Leaving _FindCommandInCommandTree ###\n" if ($self->{_iDebugFind} >= 1);
    return 1;
}

sub _RunCodeDirective
{
    # This method will execute the code directives when called.  It performs some sanity checking
    # before it actually runs the commands
    # Required:
    #   $self->{_hCommandTreeAtLevel}   hash_ref
    #   $self->{_hCommandDirectives}    hash_ref
    #   $self->{_aCommandArguments}     array_ref
    my $self = shift;
    
    if(!$self->{_hCommandDirectives}) 
    {
        # This is for processing a default command at each level
        if ((exists $self->{_hCommandTreeAtLevel}->{''}) && (exists $self->{_hCommandTreeAtLevel}->{''}->{code}))
        {
            # The default command exists and has a code directive
#            my $save = $self->{_hCommandDirectives};
            $self->{_hCommandDirectives} = $self->{_hCommandTreeAtLevel}->{''};
#            $self->_RunCommand();
#            $self->{_hCommandDirectives} = $save;
#            return;
        }
        my ($sCommandName) = $self->_GetFullCommandName();
        $self->error( "$sCommandName: unknown command\n");
        return undef;
    }

    # Lets check and verify the max and min values for number of arguments if they exist
    # TODO Instead of printing an error, we should print the command syntax 
    if (exists($self->{_hCommandDirectives}->{minargs}) && @{$self->{_aCommandArguments}} < $self->{_hCommandDirectives}->{minargs}) 
    {
        $self->error("Too few args!  " . $self->{_hCommandDirectives}->{minargs} . " minimum.\n");
        return undef;
    }
    if (exists($self->{_hCommandDirectives}->{maxargs}) && @{$self->{_aCommandArguments}} > $self->{_hCommandDirectives}->{maxargs}) 
    {
        $self->error("Too many args!  " . $self->{_hCommandDirectives}->{maxargs} . " maximum.\n");
        return undef;
    }

    # Lets add support for authenticated commands
    if ( exists $self->{_hCommandDirectives}->{auth} && $self->{_hCommandDirectives}->{auth} == 1 )
    {
        my $iSuccess = $self->_AuthCommand();
        if ( $iSuccess == 1 ) { $self->_RunCommand(); }
    }
    else { $self->_RunCommand(); }
    
    return;
}

sub _AuthCommand
{
    # This method will perform authentication for a command.  
    # Return:
    #   1 = successful authentication
    #   0 = failed authentication
    my $self = shift;
    my $OUT = $self->{OUT};

    my $bAuthStatus = 0;
    my $iAttempt = 1;
    my $sStoredUsername = "";
    my $sStoredPassword = "";
    my $sStoredSalt = "";
    my $iCryptID;

    my $oAuth = new Term::RouterCLI::Auth();
    

    print "--DEBUG AUTH 0-- ### Entering _AuthCommand ###\n" if ($self->{_iDebugAuth} >= 1);

    my $iMaxAttempt = 3;
    if ( exists $self->{_oConfig}->{_hConfigData}->{auth}->{max_attempts} ) { $iMaxAttempt = $self->{_oConfig}->{_hConfigData}->{auth}->{max_attempts}; }
    
    my $sAuthMode = "shared";
    if ( exists $self->{_oConfig}->{_hConfigData}->{auth}->{mode} ) { $sAuthMode = $self->{_oConfig}->{_hConfigData}->{auth}->{mode}; }
    
    print "--DEBUG AUTH 1-- iMaxAttempt: $iMaxAttempt\n" if ($self->{_iDebugAuth} >= 1);
    print "--DEBUG AUTH 1-- sAuthMode: $sAuthMode\n" if ($self->{_iDebugAuth} >= 1);
    
    

    
    if ($sAuthMode eq "shared")
    {
        if ( exists $self->{_oConfig}->{_hConfigData}->{auth}->{password} ) 
        { 
            $sStoredPassword = $self->{_oConfig}->{_hConfigData}->{auth}->{password};
            ($iCryptID, $sStoredSalt, $sStoredPassword) = $oAuth->SplitPasswordString(\$sStoredPassword);
        }   
        
        # Lets not prompt for a password if the password is blank in the configuration file or does not exist
        # in the configuration file
        if ( $$sStoredPassword eq "" )
        {
            print "--DEBUG AUTH 2-- No password found for shared auth mode, exiting\n" if ($self->{_iDebugAuth} >= 1);
            print "--DEBUG AUTH 2-- ### Leaving _AuthCommand ###\n" if ($self->{_iDebugAuth} >= 1);
            # Return code 1 = "success"
            return 1;
        }

        while ($iAttempt <= $iMaxAttempt) 
        {
            $self->ChangeActivePrompt("Password: ");
            my $sPassword = $oAuth->PromptForPassword();
            print "--DEBUG AUTH 2-- sPassword: $$sPassword\n" if ($self->{_iDebugAuth} >= 1);
                
            my $sEncryptedPassword = $oAuth->EncryptPassword($iCryptID, $sPassword, $sStoredSalt);
            print "--DEBUG AUTH 2-- sEncryptedPassword: $$sEncryptedPassword\n" if ($self->{_iDebugAuth} >= 1);
    
            # TODO Need to provide a way for users to change the password
            if ($$sEncryptedPassword eq $$sStoredPassword) 
            {
                print "--DEBUG AUTH 2-- Match Found\n" if ($self->{_iDebugAuth} >= 1);
                $bAuthStatus = 1;
                last;
            }
            if ($iAttempt == $iMaxAttempt) 
            {
                print $OUT "Too many failed authentication attempts!\n\n";
                $bAuthStatus = 0;
                last;
            }
            $iAttempt++;
        }
    }
    elsif ($sAuthMode eq "user")
    {
        my $sUserAuthMode = "local";
        
        while ($iAttempt <= $iMaxAttempt) 
        {
            $self->ChangeActivePrompt("Username: ");
            my $sUsername = ${$oAuth->PromptForUsername()};
            print "--DEBUG AUTH 3-- sUsername: $sUsername\n" if ($self->{_iDebugAuth} >= 1);
            
            $self->ChangeActivePrompt("Password: ");
            my $sPassword = $oAuth->PromptForPassword();
            print "--DEBUG AUTH 3-- sPassword: $$sPassword\n" if ($self->{_iDebugAuth} >= 1);

            unless ( exists $self->{_oConfig}->{_hConfigData}->{auth}->{user}->{$sUsername} ) 
            { 
                print "--DEBUG AUTH 3.1-- iAttempt: $iAttempt\n" if ($self->{_iDebugAuth} >= 1);
                $iAttempt++;
                next;
            }
            
            # This is where we add support for things like RADIUS or TACACS from the configuration file
            if ( exists $self->{_oConfig}->{_hConfigData}->{auth}->{user}->{$sUsername}->{authmode} )
            {
                $sUserAuthMode = $self->{_oConfig}->{_hConfigData}->{auth}->{user}->{$sUsername}->{authmode};
            }

            # We do not allow undefined passwords
            unless ( exists $self->{_oConfig}->{_hConfigData}->{auth}->{user}->{$sUsername}->{password} ) 
            { 
                print "--DEBUG AUTH 3.2-- iAttempt: $iAttempt\n" if ($self->{_iDebugAuth} >= 1);
                $iAttempt++;
                next;
            }  
            $sStoredPassword = $self->{_oConfig}->{_hConfigData}->{auth}->{user}->{$sUsername}->{password};
            ($iCryptID, $sStoredSalt, $sStoredPassword) = $oAuth->SplitPasswordString(\$sStoredPassword);

            my $sEncryptedPassword = $oAuth->EncryptPassword($iCryptID, $sPassword, $sStoredSalt);
            print "--DEBUG AUTH 3-- sEncryptedPassword: $$sEncryptedPassword\n" if ($self->{_iDebugAuth} >= 1);          
            
            if ($$sEncryptedPassword eq $$sStoredPassword) 
            {
                print "--DEBUG AUTH 3-- Match Found\n" if ($self->{_iDebugAuth} >= 1);
                $self->{_sActiveLoggedOnUser} = $sUsername;
                
                # We need to clear and load the new command history file for this user
                if ($self->{_oHistory}->{_bEnabled} == 1 )
                {
                    $self->{_oHistory}->SaveCommandHistoryToFile();
                    $self->{_oHistory}->ClearHistory();
                    my $sNewHistoryFilename = './logs/.cli-history-' . $sUsername;
                    $self->{_oHistory}->SetFilename($sNewHistoryFilename);
                    $self->{_oHistory}->LoadCommandHistoryFromFile();
                }
                
                $bAuthStatus = 1;
                last;
            }

            if ($iAttempt == $iMaxAttempt) 
            {
                print $OUT "Too many failed authentication attempts!\n\n";
                $bAuthStatus = 0;
                last;
            }
            $iAttempt++;
        }
    }



    print "--DEBUG AUTH 0-- ### Leaving _AuthCommand ###\n" if ($self->{_iDebugAuth} >= 1);
    return $bAuthStatus;
}

sub _RunCommand
{
    # This method will actually run the commands called out in the code directives
    # Required:
    #   $self->{_hCommandDirectives}    hash_ref
    my $self = shift;
    my $OUT = $self->{OUT};

    if (exists $self->{_hCommandDirectives}->{code}) 
    {
        my $oCode = $self->{_hCommandDirectives}->{code};
        # If oCode is a code ref, call it, else it's a string, print it.
        if (ref($oCode) eq 'CODE') 
        {
            # This is where we actually run the code. All commands and arguments are in the object
            eval { &$oCode($self) };
            $self->error($@) if $@;
        } 
        else { print $OUT $oCode; }
    } 
    else 
    {
        if (exists $self->{_hCommandDirectives}->{cmds}) 
        { 
            print $OUT $self->_GetCommandSummaries(); 
        } 
        else 
        {
            my ($sCommandName) = $self->_GetFullCommandName();
            $self->error("The $sCommandName command has no code directive to call!\n"); 
        }
    }

    return;
}

sub _CompletionFunction
{
    # This method is the entry point to the ReadLine completion callback and will complete a string
    # of data against the command tree.
    # Required:
    #   string (The word directly to the left of the cursor)
    #   string (The entire line)
    #   int (the position in the line of the beginning of $text)

    my $self = shift;
    $self->{_sStringToComplete} = shift; 
    $self->{_sCompleteRawline} = shift; 
    $self->{_iStringToCompleteTextStartPosition} = shift;
    my $OUT = $self->{OUT};


    # Lets figure out where the cursor is currently at and thus how long the original line is
    $self->{_iCurrentCursorLocation} = $self->{_oTerm}->Attribs->{'point'};

    if ($self->{_iDebugCompletion} >= 1)
    {
        print "\n";
        print "--DEBUG Complete 0-- ### Entering _CompletionFunction ###\n";
        print "--DEBUG Complete 0-- Values passed in to the function and computed from those values\n";
        print "--DEBUG Complete 0-- _sStringToComplete: $self->{_sStringToComplete}\n" if defined $self->{_sStringToComplete};
        print "--DEBUG Complete 0-- _sCompleteRawline: $self->{_sCompleteRawline}\n" if defined $self->{_sCompleteRawline};  
        print "--DEBUG Complete 0-- _iStringToCompleteTextStartPosition: $self->{_iStringToCompleteTextStartPosition}\n" if defined $self->{_iStringToCompleteTextStartPosition}; 
        print "--DEBUG Complete 0-- _iCurrentCursorLocation: $self->{_iCurrentCursorLocation}\n";
        print "\n";
    }
        
    # If there is any white space at the start or end of the command lets remove it just to be safe 
    $self->{_sCompleteRawline} =~ s/^\s+//g;  
    $self->{_sCompleteRawline} =~ s/\s+$//g; 



    # Parse the _sCompleteRawline in to a series of command line tokens
    ($self->{_aCommandTokens}, $self->{_iTokenNumber}, $self->{_iTokenOffset}) = $self->{_oParser}->parse_line(
        $self->{_sCompleteRawline},
        messages=>0, 
        cursorpos=>$self->{_iCurrentCursorLocation}, 
        fixclosequote=>1
    );

    if ($self->{_iDebugCompletion} >= 1) 
    {
        print "--DEBUG Complete 1-- Data returned from the parser function\n";
        print "--DEBUG Complete 1-- _aCommandTokens: ";
        foreach (@{$self->{_aCommandTokens}}) {print "$_, ";}
        print "\n";        
        print "--DEBUG Complete 1-- _iTokenNumber: $self->{_iTokenNumber}\n" if (defined $self->{_iTokenNumber});
        print "--DEBUG Complete 1-- _iTokenOffset: $self->{_iTokenOffset}\n" if (defined $self->{_iTokenOffset});
        print "\n";
    }
    
    # Punt if nothing comes back from the parser
    unless (defined($self->{_aCommandTokens})) { print "ERROR 1001\n"; return; }

    # Lets try and find the command in the command tree
    $self->_FindCommandInCommandTree();



    # --------------------------------------------------------------------------------
    # Process Arguments
    # --------------------------------------------------------------------------------
    # Lets check to see if there are any arguments returned from the Find function. The three use cases are:
    # 1) There are no arguments, meaning everything is a command found in the command tree
    # 2) There are multiple matches found for the command abbreviation that was entered
    # 3) No match was found
    #   3a) The command was typed in wrong
    #   3b) The values typed in are in fact arguments and not part of the command at all
    #   3c) The values need to be passed to a method defined in the args directive to see if they are commands
    #   3d) There was nothing entered on the command line
    my $iNumberOfArguments = @{$self->{_aCommandArguments}};
    print "--DEBUG Complete 3-- iNumberOfArguments: $iNumberOfArguments\n" if ($self->{_iDebugCompletion} >= 1);
    if ($iNumberOfArguments > 0)
    {
        # Use Cases 2 and 3
        # Lets figure out how many matches there are for that first argument that could not be completed
        my @aCommandsThatMatchAtThisLevel = keys(%{$self->{_hCommandTreeAtLevel}});
        @aCommandsThatMatchAtThisLevel = grep {/^$self->{_aCommandArguments}->[0]/ } @aCommandsThatMatchAtThisLevel;
        my $iNumberOfCommandsThatMatchAtThisLevel = @aCommandsThatMatchAtThisLevel;
        
        print "--DEBUG Complete 4-- Use Case 2 and 3\n" if ($self->{_iDebugCompletion} >= 1);
        print "--DEBUG Complete 4-- iNumberOfCommandsThatMatchAtThisLevel: $iNumberOfCommandsThatMatchAtThisLevel\n" if ($self->{_iDebugCompletion} >= 1);
        if ($iNumberOfCommandsThatMatchAtThisLevel > 1)
        {
            # Use Case 2: There was more than one match found.  So we need to print out the options for just these commmands
            print "--DEBUG Complete 4-- Use Case 2\n" if ($self->{_iDebugCompletion} >= 1);
            $self->_RewriteLine();

            # Print out possible options for the matches that were found
            print $OUT "\n";
            print $OUT $self->_GetCommandSummaries(\@aCommandsThatMatchAtThisLevel);

            # We need to redraw the prompt and command line options since we are going to output text via _GetCommandSummaries
            $self->{_oTerm}->rl_on_new_line();
            return;
        }
        else
        {
            # Use Case 3: There were no matches found for this argument, meaning that the argument is not found in the 
            # command tree so the arguments must truely be arguments or they are incorrectly entered commands.  
            # But before we can know this for sure, lets check for an args directive.
            
            print "--DEBUG Complete 4-- Use Case 3\n" if ($self->{_iDebugCompletion} >= 1);
            if (exists $self->{_hCommandDirectives}->{args} && !exists $self->{_hCommandDirectives}->{minargs})
            {
                # Use Case 3c: This is for something like "help" or "no" that needs to restart the completion at the
                # beginning of the command tree.  So we will need to check the args directive
                print "--DEBUG Complete 4-- Use Case 3c\n" if ($self->{_iDebugCompletion} >= 1);
                

                if (ref($self->{_hCommandDirectives}->{args}) eq 'CODE') 
                {
                    # This is where we call the subroutine listed in the args directive
                    eval { &{$self->{_hCommandDirectives}->{args}}($self) };
                } 
                
                $self->_RewriteLine();
            }
            elsif (!exists $self->{_hCommandDirectives}->{args} && (exists $self->{_hCommandDirectives}->{minargs} && $self->{_hCommandDirectives}->{minargs} > 0))
            {
                # Use Case 3b: The arguments are in fact arguments
                print "--DEBUG Complete 4-- Use Case 3b\n" if ($self->{_iDebugCompletion} >= 1);
                $self->_RewriteLine();
                return;
            }
            else
            {
                # Use Case 3a: The command was typed in wrong
                print "--DEBUG Complete 4-- Use Case 3a\n" if ($self->{_iDebugCompletion} >= 1);
                $self->_RewriteLine();
            }
            
        }
    }
    else
    {
        if (!exists $self->{_aFullCommandName}->[0] || $self->{_aFullCommandName}->[0] eq "")
        {
            # Use Case 3d: There was nothing entered on the command line.  So we need to print out all options at that level
            print "--DEBUG Complete 4-- Use Case 3d\n" if ($self->{_iDebugCompletion} >= 1);
            $self->_RewriteLine();

            # Print out possible options for the matches that were found
            print $OUT "\n";
            print $OUT $self->_GetCommandSummaries();

            # We need to redraw the prompt and command line options since we are going to output text via _GetCommandSummaries
            $self->{_oTerm}->rl_on_new_line();
            return;            
        }
        else
        {
            # Use Case 1: There were no arguments found, so everything is a full blown command
            print "--DEBUG Complete 4-- Use Case 1\n" if ($self->{_iDebugCompletion} >= 1);
            $self->_RewriteLine();            
        }
    }
    # --------------------------------------------------------------------------------
    
    # These next two lines will make the screen scroll up like it does on a router
    # If we are in a internal loop, like processing the args directive lets not scroll 
    # the screen as that will just add extra lines when we do not want them
    if ($self->{_sStringToComplete} ne "NONE")
    {
        print $OUT "\n";
        $self->{_oTerm}->rl_on_new_line();
    }
    
    # If there is nothing to do, meaning, there is no command to complete, then lets print out 
    # the command options at that level.  If there are no options at that level, print <cr>.
    # If there are currently no commands found, then lets not print either
    my $iNumberOfCommands = @{$self->{_aFullCommandName}};
    if ($self->{_sStringToComplete} eq "" && $iNumberOfCommands > 0)
    {
        print "--DEBUG Complete 4-- Lets get the data from _GetCommandSummaries\n" if ($self->{_iDebugCompletion} >= 1);
        print $OUT $self->_GetCommandSummaries(); 
    }


    print "--DEBUG Complete 0-- ### Leaving _CompletionFunction ###\n" if ($self->{_iDebugCompletion} >= 1);
    return;
}

sub _RewriteLine
{
    # This method will do the actual rewriting of the command line during command completion
    # Required:
    my $self = shift;
    
    print "\n--DEBUG RewriteLine 0-- ### Entering _RewriteLine Function ###\n" if ($self->{_iDebugCompletion} >= 1);
    
    my ($sCommands, $iCommandsLength) = $self->_GetFullCommandName();
    my ($sArguments, $iArgumentLength) = $self->_GetFullArgumentsName();
    my $iCurrentPoint = $self->{_iCurrentCursorLocation};

    # We need to set the cursor to the end of the new fully completed line
    my $iNewPointLocation = $iCommandsLength + $iArgumentLength;
        
    if ($self->{_iDebugCompletion} >= 1)
    {
        print "--DEBUG RewriteLine 1-- iCurrentPoint: $iCurrentPoint\n";
        print "--DEBUG RewriteLine 1-- sCommands: $sCommands\n";
        print "--DEBUG RewriteLine 1-- iCommandsLength: $iCommandsLength\n";
        print "--DEBUG RewriteLine 1-- sArguments: $sArguments\n";
        print "--DEBUG RewriteLine 1-- iArgumentLength: $iArgumentLength\n";        
        print "--DEBUG RewriteLine 1-- iNewPointLocation: $iNewPointLocation\n";  
    }

    $self->{_oTerm}->Attribs->{'line_buffer'} = $sCommands . $sArguments;
    $self->{_oTerm}->Attribs->{'point'} = $iNewPointLocation;


    print "--DEBUG RewriteLine 0-- ### Leaving _RewriteLine Function ###\n" if ($self->{_iDebugCompletion} >= 1);
}


return 1;
