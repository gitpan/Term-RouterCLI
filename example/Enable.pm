#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Term::RouterCLI                                      #
# Class:       Enable                                               #
# Description: Example Enable command tree for building a Router    #
#              (Stanford) style CLI                                 #
#                                                                   #
# Written by:  Bret Jordan (jordan at open1x littledot org)         #
# Created:     2011-02-21                                           #
##################################################################### 
#
#
#
#
package Enable;

use strict;
use Term::RouterCLI::Languages;
use UserExec;
use Enable::Show; 
use Enable::Configure::Terminal;



sub CommandTree {
    my $self = shift;
    my $lang = new Term::RouterCLI::Languages( _oParent => $self );
    my $strings = $lang->LoadStrings("Enable");
    my $hash_ref = {};

    $hash_ref = {
        "show"  => {
            desc    => $strings->{show_d},
            help    => $strings->{show_h},
            cmds    => &Enable::Show::CommandTree($self)
        },
        "exit"  => {
            desc    => $strings->{exit_d},
            help    => $strings->{exit_h},
            maxargs => 0,
            code    => sub { shift->Exit(); }
        },
        "end" => {
            desc    => $strings->{end_d},
            help    => $strings->{end_h},
            maxargs => 0,
            code    => sub {
                my $self = shift;
                $self->SetPromptLevel('> ');
                $self->SetPrompt($self->{_oConfig}->{_hConfigData}->{hostname});
                $self->CreateCommandTree(&UserExec::CommandTree($self));
            }
        },
        "configure" => {
            desc    => $strings->{configure_d},
            help    => $strings->{configure_h},
            cmds    => {
                "terminal" => { 
                    code => sub {
                        my $self = shift;
                        $self->SetPromptLevel('(config)# ');
                        $self->SetPrompt($self->{_oConfig}->{_hConfigData}->{hostname});
                        $self->CreateCommandTree(&Enable::Configure::Terminal::CommandTree($self));
                    } 
                }
            }
        },
    };
    

    # UserExec level commands should also be avaliable in Enable Mode
    my $hash_ref_additional = &UserExec::CommandTree($self);
    
    # Enable level commands should take presidence over UserExec commands if they are duplicates
    my %hash = (%$hash_ref_additional, %$hash_ref);
    
    return(\%hash);
}


return 1;
