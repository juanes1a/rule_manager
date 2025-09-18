FROM #{elixir_1.17_alpine}# as builder
#ARG AZURE_ACCESS_TOKEN
RUN apk add build-base git
WORKDIR /app
# To generate mix cache
RUN mix local.hex --force \
    && mix local.rebar --force
COPY mix.* .
# caché de dependencias descargada si existe
COPY cache ./cache/
# Cuando requiere dependencias desde un repositorio de azure devops
#RUN git config --global http.https://grupobancolombia.visualstudio.com/Vicepresidencia%20Servicios%20de%20Tecnolog%C3%ADa/_git/NU0025001_fflags_clients.extraheader "AUTHORIZATION: bearer $AZURE_ACCESS_TOKEN"
# To use cache or download and generate compiled deps cache
RUN $WORKDIR/elixir_cache.sh
# Ensure use of .dockerignore file to avoid copying unnecessary files
COPY . .
# To generate compiled application and run static code analysis
RUN mix ca.release --skiptest


FROM #{elixir_1.17_alpine}#
ENV USER=#{elixir_1.17_alpine-user}#
ENV APP_NAME=rule_manager_evaluator
ENV REPLACE_OS_VARS=true
EXPOSE #{container-port}#
RUN apk update && apk upgrade && apk add bash && mkdir -p $WORKDIR/rel/$APP_NAME/var && chown -R $USER:$USER $WORKDIR/rel/$APP_NAME/
COPY --from=builder /app/_build/release/artifact/$APP_NAME.tar.gz .
RUN tar -xzf $APP_NAME.tar.gz -C $WORKDIR/ \
    && rm -f $APP_NAME.tar.gz \
    && ls -Rl $WORKDIR \
    && $WORKDIR/extra_ca_certs.sh $EXTRA_CA_CERTS
VOLUME $WORKDIR/rel/$APP_NAME/etc
USER $USER
ENTRYPOINT exec $WORKDIR/bin/$APP_NAME start