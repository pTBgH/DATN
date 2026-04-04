FROM quay.io/keycloak/keycloak:22.0.5

# Copy themes vào trong image
COPY ./custom-job7189 /opt/keycloak/themes/custom-job7189
COPY ./custom-job7189a /opt/keycloak/themes/custom-job7189a

# Copy realm config — sẽ được import khi container start với --import-realm flag
RUN mkdir -p /opt/keycloak/data/import
COPY ./realm-infra.json /opt/keycloak/data/import/realm-infra.json

# Build lại (nếu cần config optimize)
RUN /opt/keycloak/bin/kc.sh build