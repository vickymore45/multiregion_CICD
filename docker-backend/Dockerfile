FROM node:20-slim
RUN apt-get update && apt-get install -y git curl libpng-dev libonig-dev libxml2-dev zip unzip
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
RUN useradd -G www-data,root -u 1001 -d /home/user user
COPY ./backend /opt/html/backend
COPY ./entrypoint.sh /opt/entrypoint.sh
RUN chmod -Rf 775 /opt/html/backend
RUN chmod +x /opt/entrypoint.sh
WORKDIR /opt/html/backend
RUN npm install
RUN npm install --save-dev -g sequelize-cli
ENTRYPOINT ["bash","-c","/opt/entrypoint.sh"]
