import re

with open("/home/ptb/projects/DATN/infras/kong/kong.yml", "r") as f:
    content = f.read()

new_key = """-----BEGIN PUBLIC KEY-----
          MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7NPvdwavIu1CD53/djlW
          3Ojc0mWPK2l8bMxH5P+qJwKjZfY4oG0DvrFFW3Vt3tIUyZUbyJrfC9o92m6wJWgx
          xBTUP9MRPuXkj22GSDfbqY/ptFlVgO63NxCjckXbJ6oWd0BIWBo9G8EfUboYryZG
          6IQldXF8F3vNYcdet5Pn40g2PBR13xvdJ8tBWtDCZfvVPJKJk4KOr4r4hqqsHA62
          HpodTbMEy82LUgHg03PbYiLhJr+SUwqqgjfwtWXjjzu7vaLWlLYhxtisC7hKWrDq
          bUs/anKTZ0wyH4x/rUhxBvciyzlJQMUP3TUmETSxBK89XZY1vYawlsddKz03xCyc
          8QIDAQAB
          -----END PUBLIC KEY-----"""

# Regex to find old blocks
content = re.sub(r'-----BEGIN PUBLIC KEY-----.*?-----END PUBLIC KEY-----', new_key, content, flags=re.DOTALL)

with open("/home/ptb/projects/DATN/infras/kong/kong.yml", "w") as f:
    f.write(content)
