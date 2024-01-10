# AlpineLinux
FROM scratch

ARG package_version
LABEL package_version="${package_version}"

ADD ./downloads/alpine-minirootfs-${package_version}-x86_64.tar.gz /
# Overwrite repos with our custom location on local network
# ADD ./downloads/repositories /etc/apk/repositories
# Upgrade / Update / Install certificates
RUN apk upgrade --update \
	&& apk add su-exec ca-certificates
# Copy the project catalysts certificate authority
ADD ./downloads/projectcatalysts-ca.pem /usr/local/share/ca-certificates/projectcatalysts-ca
ADD ./downloads/projectcatalysts-ca-prv.pem /usr/local/share/ca-certificates/projectcatalysts-ca-prv
# Load the project catalysts certificate authority
RUN update-ca-certificates
RUN rm /var/cache/apk/*
