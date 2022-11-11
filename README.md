# My home pi boards

### Prerequirement

Need debian/ubuntu os with ssh user `pi`

### Dependencies

```bash
$ python -m pip install -r requirements.txt
$ ansible-galaxy install -r requirements.yml
```

### Using

Launch playbook

```bash
$ ansible-playbook playbook.yml -i inventories/home
```
