if which brew 2> /dev/null; then
    is_osx=true
else
    is_osx=false
fi

export PATH="$HOME/perl5/bin:$PATH"
export PERL5LIB="$HOME/perl5/lib/perl5:$PERL5LIB"
