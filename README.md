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
├── nginx/
│   └── conf.d/
│       ├── safecall.conf
│       └── safecall.https.conf.template
└── scripts/
    ├── deploy.sh
    ├── init-letsencrypt.sh
    └── renew-letsencrypt.sh
```

## 서버 이미지

`docker-compose.prod.yml`의 서버 이미지는 아래 값을 사용합니다.

```text
ghcr.io/cosh-safecall/safecall-server:latest
```

Docker image reference는 대문자를 쓰지 않도록 소문자 `cosh-safecall`로 맞춥니다.

## HTTPS 인증서

HTTP 배포와 도메인 연결이 성공한 뒤 EC2 운영 디렉터리에서 초회 인증서를 발급합니다.

```bash
cd /home/ec2-user/safecall
LETSENCRYPT_EMAIL=your-email@example.com bash scripts/init-letsencrypt.sh
```

갱신은 `renew-letsencrypt.sh`를 crontab에 등록해서 자동화합니다.

민감값은 이 레포에 커밋하지 않습니다.

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

