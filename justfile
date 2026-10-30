set lists
set unstable
set shell := ['nu', '-c']

default: dash

nodelist := ["10.128.16.1", "10.128.16.2", "10.128.16.3"]
nodes := join_list(nodelist, ',')
node := "10.128.16.1"
version := "v1.14.4"
image := "8b690dfa8f9cebd7208a3f2f728f06377b5f468334f480485ad3f77d0cbf107d"
endpoint := "https://10.128.128.128:6443"

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

upgrade node:
    talosctl upgrade -n {{node}} --image factory.talos.dev/metal-installer-secureboot/{{image}}:{{version}}
apply *flags:
    #!/usr/bin/env nu
    let patches = (
        glob "talos/common/**/*.yaml"
        | each {|p| ["--config-patch", $"@($p)"] }
        | flatten
    )
    let secrets = (
        age -d
            -i ~/.ssh/id_ed25519
            -i age/identities.txt
            secrets/talos-cred.age
        | to text
    )
    echo {{nodelist}} | each {|node| 
        let name = match $node {
            "10.128.16.1" => "betelgeuse.yaml"
            "10.128.16.2" => "polaris.yaml"
            "10.128.16.3" => "sirius.yaml"
            _ => "sol"
        }
        $secrets | (talosctl gen config outer-space {{endpoint}}
            --with-secrets /dev/stdin
            --install-disk /dev/nvme0n1
            --install-image factory.talos.dev/metal-installer-secureboot/{{image}}:{{version}}
            ...$patches
            --config-patch $"@talos/($name)"
            --output-types controlplane --output -
        ) | talosctl apply-config -n $node --file /dev/stdin {{flags}}
    }

encrypt:
    age -R age/recipients.txt -o secrets/talos-cred.age ~/.talos/secrets.yaml


gatewayCRDs:
    kubectl apply --server-side -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.6.1/config/crd/experimental/gateway.networking.k8s.io_gatewayclasses.yaml
    kubectl apply --server-side -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.6.1/config/crd/experimental/gateway.networking.k8s.io_gateways.yaml
    kubectl apply --server-side -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.6.1/config/crd/experimental/gateway.networking.k8s.io_httproutes.yaml
    kubectl apply --server-side -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.6.1/config/crd/experimental/gateway.networking.k8s.io_referencegrants.yaml
    kubectl apply --server-side -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.6.1/config/crd/experimental/gateway.networking.k8s.io_grpcroutes.yaml
    kubectl apply --server-side -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.6.1/config/crd/experimental/gateway.networking.k8s.io_backendtlspolicies.yaml
    kubectl apply --server-side -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.6.1/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml
    kubectl apply --server-side -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.6.1/config/crd/experimental/gateway.networking.k8s.io_listenersets.yaml
    kubectl apply --server-side -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.6.1/config/crd/experimental/gateway.networking.k8s.io_tcproutes.yaml
    kubectl apply --server-side -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.6.1/config/crd/experimental/gateway.networking.k8s.io_udproutes.yaml
bootstrap: gatewayCRDs
    #!/usr/bin/env nu

    (helm upgrade --install prometheus-crd -n observability --wait --create-namespace
        oci://ghcr.io/prometheus-community/charts/prometheus-operator-crds
    )

    (helm upgrade --install cilium --wait --wait-for-jobs
        oci://quay.io/cilium/charts/cilium -n kube-system
        -f kubernetes/infra/kube-system/cilium/app/values.yaml
    )

    (helm upgrade --install coredns  --wait --wait-for-jobs
        oci://ghcr.io/coredns/charts/coredns -n kube-system
        -f kubernetes/infra/kube-system/coredns/app/values.yaml
    )

    (helm upgrade --install flux-operator --wait --wait-for-jobs
        oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator
        --namespace flux-system --create-namespace
        -f kubernetes/infra/flux-system/flux-operator/app/values.yaml
    )

    kubectl create namespace external-secrets

    (age -d
        -i ~/.ssh/id_ed25519
        -i age/identities.txt
        secrets/flux-secret.age
    ) | kubectl apply -f -

    (age -d
        -i ~/.ssh/id_ed25519
        -i age/identities.txt
        secrets/doppler-auth.age
    ) | kubectl apply -f -

    (kubectl apply -f
        kubernetes/infra/flux-system/flux-instance/app/fluxinstance.yaml
    )
    
