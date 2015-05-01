#!/bin/bash

# ANY error should stop the script and exit non-zero
# This is why we need to switch to makefiles
set -e
# turn on for verbose logging
# set -xv

OS=$(uname -s)

case $OS in
    "Linux" | "Darwin" ) ;; # good
    "*"                ) echo "Unknown OS: ${OS}"; exit 1 ;;
esac

cd $(dirname $0)

MAGLEV_HOME=$(cd ../../.. ; pwd)
GEMSTONE=$MAGLEV_HOME/gemstone
GSVERSION=3.1.0.2.1-64                       # HACK

./yacc.sh

if test $? -ne 0; then
  echo "  byacc failed"
  exit 1
fi
echo "  byacc ok"

if [ -z "$CC" ]; then
    case $OS in
        "Linux" ) CC=/usr/bin/g++; ;;
        "Darwin") CC=/usr/local/bin/g++-4.9 ;;
    esac
fi

case $OS in
    "Linux" )
        EXT=so
        OSLDFLAGS="-Wl,--version-script=magparse.exp -Wl,--warn-unresolved-symbols -Wl,-Bdynamic,-hlibmagparse.${EXT} -lcrypt -lrt"
        OSCCWARN="-Wformat"
        OSCCINC=""
        ;;
    "Darwin")
        EXT=dylib
        OSLDFLAGS="-Wl,-flat_namespace -Wl,-undefined -Wl,warning -Wl,-exported_symbols_list -Wl,magparse.osx.exp"
        OSCCWARN=""
        OSCCINC="-I/usr/local/Cellar/icu4c/54.1/include"
        ;;
esac

CCWARN="-Wchar-subscripts -Wcomment -Werror -Wmissing-braces -Wmultichar -Wno-aggregate-return -Wno-unused-function -Wparentheses -Wreturn-type -Wshadow -Wsign-compare -Wsign-promo -Wswitch -Wsystem-headers -Wtrigraphs -Wtrigraphs -Wuninitialized -Wunused-label -Wunused-value -Wunused-variable -Wwrite-strings $OSCCWARN"
CCDEF="-DFLG_FAST=1 -DNOT_JAVA_VM -D_GNU_SOURCE -D_REENTRANT"
CCINC="-I$GEMSTONE/include -I. $OSCCINC"
CFLAGS="$CCDEF $CCINC $CCWARN -O3 -fPIC -fcheck-new -fmessage-length=0 -fno-exceptions -fno-strict-aliasing -g -m64 -pipe -pthread -x c++"

$CC $CFLAGS -c rubygrammar.c -o rubygrammar.o

if test $? -ne 0; then
  echo "compiling rubygrammar.o failed"
  exit 1
fi

echo "Compiling rubyast.o"
$CC $CFLAGS -c rubyast.c -o rubyast.o

if test $? -ne 0; then
  echo "compiling rubyast.o failed"
  exit 1
fi

rm -f libmagparse.${EXT}

echo "Linking libmagparse.${EXT}"
LDFLAGS="-shared -lc -ldl -lm -lpthread -m64 $OSLDFLAGS"

$CC $LDFLAGS rubyast.o rubygrammar.o -o libmagparse.${EXT}

if test $? -ne 0; then
  echo "linking libmagparse.${EXT} failed"
  exit 1
fi

chmod 555 libmagparse.${EXT}

echo "Copying libmagparse.${EXT} to $GEMSTONE/lib/"
chmod +w $GEMSTONE/lib
rm -f $GEMSTONE/lib/libmagparse-$GSVERSION.${EXT}
cp libmagparse.${EXT} $GEMSTONE/lib/libmagparse-$GSVERSION.${EXT}