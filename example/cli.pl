#!/usr/bin/perl


use lib "../lib/";
use strict;
use Term::RouterCLI;
use UserExec;



my $cli = new Term::RouterCLI('_iDebugCompletion' => 0, '_iDebugFind' => 0, '_iDebug' => 0, '_iDebugHelp' => 0, '_iDebugAuth' => 0 );

# Load the current configuration in to memory, this has to be done before we load command trees
$cli->SetConfigFilename('etc/RouterCLI.conf');
$cli->LoadConfig();



# Load initial command tree
$cli->SetLangDirectory('./lang/');
$cli->CreateCommandTree(&UserExec::UserExecMode($cli));
$cli->SetHistoryFileLength("10");
$cli->SetAuditLogFileLength("10");
$cli->PreventEscape();
$cli->ClearScreen();
$cli->PrintMOTD();
$cli->StartCLI();
$cli->SaveConfig();



