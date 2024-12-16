FROM node:20-slim as artifact
ENV PORT=3005 
ENV REACT_APP_API_URL=${REACT_APP_API_URL}
ENV REACT_APP_API_KEY=${REACT_APP_API_KEY}
ENV REACT_APP_AUTH_DOMAIN=${REACT_APP_AUTH_DOMAIN}
ENV REACT_APP_PROJECT_ID=${REACT_APP_PROJECT_ID}
ENV REACT_APP_STORAGE_BUCKET=${REACT_APP_STORAGE_BUCKET}
ENV REACT_APP_MESSAGING_SENDER_ID=${REACT_APP_MESSAGING_SENDER_ID}
ENV REACT_APP_APP_ID=${REACT_APP_APP_ID}
ENV REACT_APP_MEASUREMENT_ID=${REACT_APP_MEASUREMENT_ID}
ENV REACT_APP_VAPID_KEY=${REACT_APP_VAPID_KEY}
ENV REACT_APP_IP_REGISTRY=${REACT_APP_IP_REGISTRY}
ENV REACT_APP_ENCRYPTION_SECRET_KEY=${REACT_APP_ENCRYPTION_SECRET_KEY}

RUN apt-get update && apt-get install -y git curl libpng-dev libonig-dev libxml2-dev zip unzip
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
RUN useradd -G www-data,root -u 1001 -d /home/user user
COPY ./frontend /opt/html/frontend
RUN chmod -Rf 775 /opt/html/frontend
WORKDIR /opt/html/frontend
RUN yarn add react-scripts@latest react@latest react-dom@latest
RUN yarn install 
RUN yarn buildlocal --prod

FROM nginx:stable-alpine-slim
COPY --from=artifact /opt/html/frontend/build /opt/html/frontend/client/
COPY ./msm.conf /etc/nginx/conf.d/default.conf
COPY ./nginx.conf /etc/nginx/nginx.conf
ENTRYPOINT ["nginx", "-g", "daemon off;"]
