FROM python:3.9.0

ENV APP_HOME /app
WORKDIR ${APP_HOME}

COPY . ./

RUN pip install pip pipenv --upgrade

RUN pipenv install --skip-lock --system --dev

LABEL org.opencontainers.image.source https://github.com/JayantGoel001/Jupyter-x-Docker
LABEL org.opencontainers.image.description Docker Image of Jupyter NoteBook

CMD [ "./scripts/entrypoint.sh" ]
