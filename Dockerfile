FROM		ubuntu:16.04
MAINTAINER 	Dmytro Polushyn <dmytro.polushyn@ixiasoft.com>
ARG			BUILD

RUN 	apt-get update && apt-get install -y openssh-server less unzip curl vim iputils-ping telnetd sshpass 
RUN		rm -rf /etc/localtime && ln -s  /usr/share/zoneinfo/America/Montreal /etc/localtime

ENV		JAVA_HOME /opt/java/jdk1.8.0_121
ENV		GLASSFISH_HOME /opt/glassfish4
ENV		PATH $PATH:$JAVA_HOME/bin:$GLASSFISH_HOME/bin
RUN 	echo 'export GLASSFISH_HOME="/opt/glassfish4"' >> /etc/bashrc

RUN     cd /opt && wget http://werther:8081/artifactory/web/install/jdk-8u121-linux-x64.tar.gz && mkdir -p /opt/java && cd /opt/java && tar xzf /opt/jdk-8u121-linux-x64.tar.gz && ln -s /opt/java/jdk1.8.0_121/bin/java /usr/bin/java && \
        rm -rf /opt/jdk-8u121-linux-x64.tar.gz

RUN     curl -L -o /opt/glassfish-4.1.1.zip http://werther:8081/artifactory/web/install/glassfish-4.1.1.zip && cd /opt && unzip /opt/glassfish-4.1.1.zip && rm -rf /opt/glassfish-4.1.1.zip && \
        echo 'AS_ADMIN_PASSWORD=' > $GLASSFISH_HOME/pass && echo 'AS_ADMIN_NEWPASSWORD=admin' >> $GLASSFISH_HOME/pass && chmod 777 /opt/glassfish4/bin/asadmin

RUN     asadmin --user admin --passwordfile $GLASSFISH_HOME/pass change-admin-password --domain_name domain1 && \
        echo 'AS_ADMIN_PASSWORD=admin' > $GLASSFISH_HOME/pass && echo 'AS_ADMIN_MASTERPASSWORD=admin' >> $GLASSFISH_HOME/pass && \
	asadmin start-domain domain1; asadmin --user admin --passwordfile $GLASSFISH_HOME/pass delete-jvm-options -client; \
	asadmin --user admin --passwordfile $GLASSFISH_HOME/pass delete-jvm-options -Xmx512m; \
	asadmin --user admin --passwordfile $GLASSFISH_HOME/pass delete-jvm-options '-XX\:MaxPermSize=192m'; \
 	asadmin --user admin --passwordfile $GLASSFISH_HOME/pass create-jvm-options -server; \
 	asadmin --user admin --passwordfile $GLASSFISH_HOME/pass create-jvm-options -Xmx512m; \
 	asadmin --user admin --passwordfile $GLASSFISH_HOME/pass create-jvm-options -Xms512m; \
	asadmin --user admin --passwordfile $GLASSFISH_HOME/pass create-jvm-options '-XX\:MaxPermSize=512m';\
	asadmin --user admin --passwordfile $GLASSFISH_HOME/pass enable-secure-admin && asadmin restart-domain domain1


RUN     curl -L -o /opt/tomcat7.tar.gz  http://werther:8081/artifactory/web/install/tomcat7.tar.gz && cd /opt && tar xvzf /opt/tomcat7.tar.gz && rm -rf /opt/tomcat7.tar.gz
COPY    webconfig.xml /opt/tomcat7/conf/ditacms/webconfig.xml
RUN 	sed -i 's/<session-timeout>30/<session-timeout>480/' /opt/tomcat7/conf/web.xml
COPY	catalina.sh /opt/tomcat7/bin/catalina.sh
RUN		chmod +x /opt/tomcat7/bin/catalina.sh

RUN	echo 'export CATALINA_OPTS="-Xms512M -Xmx512M"' > /opt/tomcat7/bin/setenv.sh

RUN 	mkdir /var/run/sshd
RUN 	echo 'root:password' | chpasswd
RUN 	sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN 	echo 'StrictHostKeyChecking no' >> /etc/ssh/ssh_config
RUN 	echo 'UserKnownHostsFile=/dev/null' >> /etc/ssh/ssh_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

COPY 	.ssh.tar.gz /root/
RUN 	rm -rf /root/.ssh && cd /root && tar xvzf /root/.ssh.tar.gz

ENV 	NOTVISIBLE "in users profile"
RUN 	echo "export VISIBLE=now" >> /etc/profile

COPY    $BUILD/cmsappserver.ear /opt/glassfish4/glassfish/domains/domain1/autodeploy/
COPY	$BUILD/xeditor.war /opt/tomcat7/webapps/
COPY	$BUILD/ditacms.war /opt/tomcat7/webapps/

COPY    glassfish4 /etc/init.d/
RUN     chmod 777 /etc/init.d/glassfish4
COPY    tomcat7 /etc/init.d/
RUN 	chmod 777 /etc/init.d/tomcat7
COPY    run.sh /tmp/
RUN     chmod 777 /tmp/run.sh

CMD 	["/tmp/run.sh"]

