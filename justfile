set lists
set unstable
set shell := ['nu', '-c']

default: dash

nodelist := ["192.168.2.3", "192.168.2.4", "192.168.2.5"]
nodes := join_list(nodelist, ',')
node := "192.168.2.3"
version := "v1.14.1"
image := "8b690dfa8f9cebd7208a3f2f728f06377b5f468334f480485ad3f77d0cbf107d"

dash target=node:
    talosctl dashboard -n {{target}} 

reboot target=nodes:
    talosctl reboot -n {{target}}

shutdown target=nodes:
    talosctl shutdown -n {{target}}

# apply target=nodes:
#     age -d \
#         -i ~/.age/age-se \
#         -i ~/.ssh/id_ed25519 \
#         -i age/identities.txt \
#         talos/secrets.age \
#     | talosctl gen config outer-space https://kube.cluster.lan:6443 \
#         --with-secrets /dev/stdin \
#         --install-disk /dev/nvme0n1 \
#         --install-image factory.talos.dev/metal-installer-secureboot/{{image}}:{{version}} \
#         --config-patch @talos/patch.yaml \
#         --output-types controlplane --output - \
#     | talosctl apply-config -n {{target}} --file /dev/stdin
apply:
    #!/usr/bin/env nu
    (age -d
        -i ~/.ssh/id_ed25519
        -i ~/.age/age-se
        -i age/identities.txt
        talos/secrets.age
    ) | to text | tee {
        (talosctl gen config outer-space https://kube.cluster.lan:6443
            --with-secrets /dev/stdin
            --install-disk /dev/nvme0n1
            --install-image factory.talos.dev/metal-installer-secureboot/{{image}}:{{version}}
            --config-patch @talos/patch.yaml
            --config-patch @talos/192-168-2-3.yaml
            --output-types controlplane --output -
        ) | talosctl apply-config -n 192.168.2.3 --file /dev/stdin
    } | tee {
        (talosctl gen config outer-space https://kube.cluster.lan:6443
            --with-secrets /dev/stdin
            --install-disk /dev/nvme0n1
            --install-image factory.talos.dev/metal-installer-secureboot/{{image}}:{{version}}
            --config-patch @talos/patch.yaml
            --config-patch @talos/192-168-2-4.yaml
            --output-types controlplane --output -
        ) | talosctl apply-config -n 192.168.2.4 --file /dev/stdin
    } | (talosctl gen config outer-space https://kube.cluster.lan:6443
            --with-secrets /dev/stdin
            --install-disk /dev/nvme0n1
            --install-image factory.talos.dev/metal-installer-secureboot/{{image}}:{{version}}
            --config-patch @talos/patch.yaml
            --config-patch @talos/192-168-2-5.yaml
            --output-types controlplane --output -
    ) | talosctl apply-config -n 192.168.2.5 --file /dev/stdin

encrypt:
    age -R age/recipients.txt -o talos/secrets.age ~/.talos/secrets.yaml

bootstrap:
    #!/usr/bin/env nu
    (helm install cilium
        oci://quay.io/cilium/charts/cilium 1.20.2 -n kube-system
        -f kubernetes/infra/kube-system/cilium/app/values.yaml
    )

    (helm install flux-operator
        oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator
        --namespace flux-system --create-namespace
        -f kubernetes/infra/flux-system/flux-operator/app/values.yaml
    )
