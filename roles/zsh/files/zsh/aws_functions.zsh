# AWS IAM Identity Center helpers keep account selection explicit per shell.
aws-login() {
    local profile="${1:-}"

    if [[ -z "$profile" ]]; then
        print -u2 "Usage: aws-login PROFILE"
        return 2
    fi
    if ! aws configure list-profiles | grep -Fxq -- "$profile"; then
        print -u2 "Unknown AWS profile: $profile"
        return 2
    fi
    if ! aws sso login --profile "$profile"; then
        return 1
    fi

    export AWS_PROFILE="$profile"
    aws-who
}

aws-use() {
    local profile="${1:-}"

    if [[ -z "$profile" ]]; then
        print -u2 "Usage: aws-use PROFILE"
        return 2
    fi
    if ! aws configure list-profiles | grep -Fxq -- "$profile"; then
        print -u2 "Unknown AWS profile: $profile"
        return 2
    fi

    export AWS_PROFILE="$profile"
    aws-who
}

aws-who() {
    if [[ -z "${AWS_PROFILE:-}" ]]; then
        print -u2 "AWS_PROFILE is not set. Run aws-login PROFILE or aws-use PROFILE."
        return 2
    fi

    printf 'AWS_PROFILE=%s\n' "$AWS_PROFILE"
    aws sts get-caller-identity --profile "$AWS_PROFILE"
}
