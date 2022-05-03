from flask import Blueprint

BLUEPRINT = Blueprint("data", __name__, url_prefix="data")

@BLUEPRINT.route("/stock", methods=["GET"])
def stock():
  return {"symbol": "data"}