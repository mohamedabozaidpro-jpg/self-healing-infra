from flask import Flask, request, redirect, url_for

app = Flask(__name__)

# تخزين المهام في الذاكرة (مؤقت - بيتصفر لو السيرفر اتعمله ريستارت)
tasks = []
next_id = 1

PAGE_TEMPLATE = """
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <title>قائمة المهام</title>
    <style>
        body {{ font-family: Arial, sans-serif; max-width: 500px; margin: 40px auto; background: #f5f5f5; }}
        h1 {{ text-align: center; color: #333; }}
        form {{ display: flex; gap: 8px; margin-bottom: 20px; }}
        input[type=text] {{ flex: 1; padding: 10px; border: 1px solid #ccc; border-radius: 6px; }}
        button {{ padding: 10px 16px; border: none; border-radius: 6px; background: #2563eb; color: white; cursor: pointer; }}
        button:hover {{ background: #1d4ed8; }}
        ul {{ list-style: none; padding: 0; }}
        li {{ background: white; padding: 12px; margin-bottom: 8px; border-radius: 6px; display: flex; justify-content: space-between; align-items: center; }}
        .done {{ text-decoration: line-through; color: #888; }}
        .actions a {{ margin-left: 10px; text-decoration: none; }}
        .empty {{ text-align: center; color: #888; }}
    </style>
</head>
<body>
    <h1>📝 قائمة المهام</h1>
    <form method="POST" action="/add">
        <input type="text" name="task" placeholder="اكتب مهمة جديدة..." required>
        <button type="submit">إضافة</button>
    </form>
    <ul>
        {items}
    </ul>
</body>
</html>
"""

ITEM_TEMPLATE = """
<li>
    <span class="{cls}">{text}</span>
    <span class="actions">
        <a href="/toggle/{id}">{toggle_label}</a>
        <a href="/delete/{id}">🗑️ مسح</a>
    </span>
</li>
"""


@app.route("/health")
def health():
    return {"status": "healthy"}, 200


@app.route("/")
def index():
    if not tasks:
        items_html = '<p class="empty">لا توجد مهام حاليًا 🎉</p>'
    else:
        items_html = "".join(
            ITEM_TEMPLATE.format(
                cls="done" if t["done"] else "",
                text=t["text"],
                id=t["id"],
                toggle_label="↩️ تراجع" if t["done"] else "✅ خلصت",
            )
            for t in tasks
        )
    return PAGE_TEMPLATE.format(items=items_html)


@app.route("/add", methods=["POST"])
def add():
    global next_id
    text = request.form.get("task", "").strip()
    if text:
        tasks.append({"id": next_id, "text": text, "done": False})
        next_id += 1
    return redirect(url_for("index"))


@app.route("/toggle/<int:task_id>")
def toggle(task_id):
    for t in tasks:
        if t["id"] == task_id:
            t["done"] = not t["done"]
    return redirect(url_for("index"))


@app.route("/delete/<int:task_id>")
def delete(task_id):
    global tasks
    tasks = [t for t in tasks if t["id"] != task_id]
    return redirect(url_for("index"))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
