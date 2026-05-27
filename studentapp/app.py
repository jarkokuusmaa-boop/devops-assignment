from flask import Flask, render_template, request, redirect
import psycopg2
import os

app = Flask(__name__)

DB_HOST = os.getenv("DB_HOST", "db")
DB_NAME = os.getenv("DB_NAME", "studentapp")
DB_USER = os.getenv("DB_USER", "studentadmin")
DB_PASS = os.getenv("DB_PASS", "studentpass")


def get_connection():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )


@app.route("/", methods=["GET", "POST"])
def index():
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS messages (
            id SERIAL PRIMARY KEY,
            username VARCHAR(100),
            message TEXT
        )
    """)

    if request.method == "POST":
        username = request.form["username"]
        message = request.form["message"]

        cur.execute(
            "INSERT INTO messages (username, message) VALUES (%s, %s)",
            (username, message)
        )

        conn.commit()

        return redirect("/")

    cur.execute(
        "SELECT username, message FROM messages ORDER BY id DESC"
    )

    messages = cur.fetchall()

    cur.close()
    conn.close()

    return render_template("index.html", messages=messages)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
