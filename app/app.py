import os
import logging
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from prometheus_flask_exporter import PrometheusMetrics

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

db_url = (
    f"postgresql://{os.environ['DB_USER']}:{os.environ['DB_PASSWORD']}"
    f"@{os.environ['DB_HOST']}:{os.environ.get('DB_PORT', '5432')}/{os.environ['DB_NAME']}"
)
app.config["SQLALCHEMY_DATABASE_URI"] = db_url
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)
metrics = PrometheusMetrics(app)


class Task(db.Model):
    __tablename__ = "tasks"
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    done = db.Column(db.Boolean, default=False, nullable=False)

    def to_dict(self):
        return {"id": self.id, "title": self.title, "done": self.done}


with app.app_context():
    db.create_all()


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


@app.route("/tasks", methods=["GET"])
def get_tasks():
    tasks = Task.query.all()
    return jsonify([t.to_dict() for t in tasks])


@app.route("/tasks", methods=["POST"])
def create_task():
    data = request.get_json(silent=True)
    if not data or not data.get("title", "").strip():
        return jsonify({"error": "title is required"}), 400
    task = Task(title=data["title"].strip())
    db.session.add(task)
    db.session.commit()
    logger.info("Created task id=%s title=%s", task.id, task.title)
    return jsonify(task.to_dict()), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
