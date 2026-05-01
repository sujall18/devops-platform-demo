import json


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.get_json()["status"] == "ok"


def test_get_tasks_empty(client):
    r = client.get("/tasks")
    assert r.status_code == 200
    assert r.get_json() == []


def test_create_task(client):
    r = client.post("/tasks", data=json.dumps({"title": "Ship it"}),
                    content_type="application/json")
    assert r.status_code == 201
    body = r.get_json()
    assert body["title"] == "Ship it"
    assert body["done"] is False
    assert "id" in body


def test_create_task_missing_title(client):
    r = client.post("/tasks", data=json.dumps({}),
                    content_type="application/json")
    assert r.status_code == 400


def test_create_task_blank_title(client):
    r = client.post("/tasks", data=json.dumps({"title": "   "}),
                    content_type="application/json")
    assert r.status_code == 400


def test_get_tasks_returns_created(client):
    client.post("/tasks", data=json.dumps({"title": "Task A"}),
                content_type="application/json")
    client.post("/tasks", data=json.dumps({"title": "Task B"}),
                content_type="application/json")
    r = client.get("/tasks")
    tasks = r.get_json()
    assert len(tasks) == 2
    titles = {t["title"] for t in tasks}
    assert titles == {"Task A", "Task B"}
