#! /usr/bin/env bash

encode() {
    local x="$( echo -n "$1" | base64 )"
    echo "${x/=*}"
}

decode() {
    local x="$1"
    local n="$(( (4 - (${#x} % 4)) % 4 ))"

    for ((; n--; )) ; do
        x="${x}="
    done

    echo -n "$x" | base64 -d
}

queue_dir="$1" ; shift
cache_dir="$1" ; shift
remote="$1" ; shift
notify_url="$1" ; shift

first=1
while true ; do
    file="$( find "$queue_dir" -type f | head -n 1 )"
    if [ -z "$file" ] ; then # nothing to do
        break
    fi

    rm "$file" 2> /dev/null || continue
    encoded_ref="$( basename "$file" )"

    if [ "$first" '=' '1' ] ; then
        tmp="$( mktemp -d )"
        trap "rm -rf \"\$tmp\"; \\exit" INT TERM QUIT EXIT
    fi

    git clone "$remote" "$tmp"

    {
        ref="$( decode "$encoded_ref" )"
        code="$?"

        if [ "$code" '=' '0' ] ; then
            (
                git --work-tree="$tmp"         \
                    --git-dir="$tmp/.git"      \
                    reset --hard "$ref"        \
             || git --work-tree="$tmp"         \
                    --git-dir="$tmp/.git"      \
                    reset --hard "origin/$ref"
            ) 2> /dev/null
            code="$?"
        fi

        if [ "$code" '=' '0' ] ; then
            (
                set -e

                source "$tmp/share/spack/setup-env.sh"
                rm -f "$tmp/.gitlab-ci.yaml"

                spack release-jobs                                    \
                    --spec-set "$tmp/etc/spack/defaults/release.yaml" \
                    --mirror-url https://mirror.spack.io              \
                    --shared-runner-tag spack-k8s                     \
                    --output-file "$tmp/.gitlab-ci.yaml"              \
                    --this-machine-only                               \
                    --print-summary
            )
            code="$?"
        fi
    } 2>&1 | tee "$tmp/tmp-result"

    code="$?"
    if [ "$code" '=' '0' ] ; then
        [ -f "$tmp/.gitlab-ci.yaml" ]
        code="$?"
    fi

    true_ref="$(
        git --work-tree="$tmp" --git-dir="$tmp/.git" rev-parse "HEAD" \
            2> /dev/null )"

    if [ "$code" '=' '0' ] ; then
        json='{"cType": "application/x-yaml"}'
        mv "$tmp/.gitlab-ci.yaml" "$tmp/tmp-result"
    else
        json='{"code": 404, "cType": "text/plain"}'
    fi

    if [ -n "$true_ref" ] ; then
        encoded_true_ref="$( encode "$true_ref" )"
        code="$?"
    fi

    jsonN="${#json}"

    base_ref="$encoded_ref"

    if [ -n "$encoded_true_ref" \
         -a "$encoded_ref" '!=' "$encoded_true_ref" ] ; then
        ln -s "$encoded_true_ref" "$cache_dir/$encoded_ref"
        base_ref="$encoded_true_ref"
    fi

    (
        echo "$jsonN"
        echo "$json"
        cat "$tmp/tmp-result"
    ) > "$cache_dir/$base_ref"

    curl -X POST "$notify_url/$encoded_ref"
    if [ -n "$encoded_true_ref" ] ; then
        curl -X POST "$notify_url/$encoded_true_ref"
    fi

    rm -rf "$tmp/.*" "$tmp/*"

    first=0
done

