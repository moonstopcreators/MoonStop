from flask import Flask
import logging

logging.basicConfig(level=logging.DEBUG)

from moonstop.api import data

API_URL_PREFIX = "/moonstop"

APIS = (
    data,
)

def create_app(api_url_prefix=API_URL_PREFIX, apis=APIS):
    app = Flask(__name__)
    for api in apis:
        blueprint = api.BLUEPRINT
        app.register_blueprint(
          blueprint,
          url_prefix="/".join((api_url_prefix, blueprint.url_prefix))
        )
    return app


if __name__ == "__main__":
    app = create_app()
    app.run(debug=True)
