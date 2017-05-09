#!/bin/sh
service ssh start
service glassfish4 start
service tomcat7 start
while :; do
            sleep 5
        done

