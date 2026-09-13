# SafeCall_infra

SafeCall 서버 인프라 설정 레포입니다.

개발용 API 도메인은 아래 값을 사용합니다.

```text
api.dev-safecall.r-e.kr
```

## 구성

```text
SafeCall_infra/
├── docker-compose.prod.yml
└── nginx/
    └── conf.d/
        └── safecall.conf
```

## 배포 전 수정할 값

`docker-compose.prod.yml`의 이미지 이름은 실제 GitHub 계정 또는 조직명에 맞춰 변경합니다.

```text
ghcr.io/OWNER/safecall-server:latest
```

예시:

```text
ghcr.io/실제_GITHUB_OWNER/safecall-server:latest
```

민감값은 이 레포에 커밋하지 않습니다.
