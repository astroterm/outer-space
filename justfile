set lists
set unstable
set shell := ['nu', '-c']

default: dash

nodelist := ["192.168.2.3", "192.168.2.4", "192.168.2.5"]
nodes := join_list(nodelist, ',')
node := "192.168.2.3"

dash target=node:
    talosctl dashboard -n {{target}} 

reboot target=nodes:
    talosctl reboot -n {{target}}

shutdown target=nodes:
    talosctl shutdown -n {{target}}

apply image='8b690dfa8f9cebd7208a3f2f728f06377b5f468334f480485ad3f77d0cbf107d' version='v1.14.0' target=nodes:
    age -d \
        -i ~/.age/age-se \
        -i ~/.ssh/id_ed25519 \
        -i age/identities.txt \
        talos/secrets.age \
    | talosctl gen config outer-space https://kube.cluster.lan:6443 \
        --with-secrets /dev/stdin \
        --install-disk /dev/nvme0n1 \
        --install-image factory.talos.dev/metal-installer-secureboot/{{image}}:{{version}} \
        --config-patch @talos/patch.yaml \
        --output-types controlplane --output - \
    | talosctl apply-config -n {{target}} --file /dev/stdin

encrypt:
    age -R age/recipients.txt -o talos/secrets.age ~/.talos/secrets.yaml