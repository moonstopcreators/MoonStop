FROM python:3.9

WORKDIR /

COPY . .

RUN pip install --trusted-host pypi.python.org -r requirements.txt

RUN python setup.py install

CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 'moonstop.app:create_app()'
