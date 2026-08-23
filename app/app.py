from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    return "<h1>Hello from Derick's Terraform + Docker + Ansible project!</h1>"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
