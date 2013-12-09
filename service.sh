#!/bin/bash

# Our coins to run
COINS="litecoin"

# Change this to your checkouts folder if you wish to run the script outside the WORKDIR
WORKDIR=$PWD

cd $WORKDIR

case $1 in
  'start')
    for coin in $COINS; do
      echo -n "Starting ${coin}d ... "
      ps ax | grep -q "${coin}d -datadir=testnet/$coin -[d]aemon" && echo " Already running" || {
        coins/${coin}/src/${coin}d -datadir=testnet/$coin -daemon &>/dev/null && echo OK || echo FAIL
      }
    done

    echo -n "Waiting for coind"
    for i in 1 2 3 4 5 6 7 8 9 10; do
      echo -n .
      sleep 1
    done
    echo ""

    echo -n "Starting litecoin stratum ... "
    LTCADDRESS=$(coins/litecoin/src/litecoind -datadir=testnet/litecoin getaccountaddress "")
    echo -n "WALLET=${LTCADDRESS} "
    sed -i -e "s/^CENTRAL_WALLET.*/CENTRAL_WALLET = '$LTCADDRESS'/" mining/stratum-mining/conf/config.py
    cd mining/stratum-mining
    /opt/local/bin/twistd-2.7 -y launcher.tac &>/dev/null && echo OK || echo FAIL
    cd ../../
    ;;

  'stop')
    for coin in $COINS; do
      echo -n "Stopping ${coin}d ... "
      coins/${coin}/src/${coin}d -datadir=testnet/$coin stop &>/dev/null && echo OK || echo FAIL
    done
    echo -n "Stopping stratums ... "
    TWISTPID=$(cat mining/stratum-mining/twistd.pid 2>/dev/null)
    [[ ! -z $TWISTPID ]] && kill $TWISTPID && echo OK || echo " no PID"
    ;;

  'clean')
    $0 stop
    for coin in $COINS; do
      rm -fR testnet/${coin}/testnet3/wallet.dat
    done
    /opt/local/bin/mysql5 -h localhost -u root -proot mpos -e "truncate shares; truncate blocks; truncate shares_archive; truncate statistics_shares; truncate transactions; update settings set value = 0 where name = 'pps_last_share_id'; update settings set value = 0 where name = 'last_accounted_block_id'; truncate notifications;"
    ;;
esac
