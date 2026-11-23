# ==============================================================================
# [1단계: 빌드 스테이지 (Builder)]
# 호스트 OS(Ubuntu 24.04)와 동일한 noble 기반 Java 21 JDK 환경에서
# 소스를 컴파일하여 실행 가능한 단일 JAR 파일 생성
# ==============================================================================
FROM eclipse-temurin:21-jdk-noble AS builder

# 컨테이너 내부 작업 디렉터리 설정
WORKDIR /app

# 1. Maven 래퍼(.mvn, mvnw)와 의존성 명세서(pom.xml)를 소스보다 먼저 복사
# -> Java 코드를 수정하더라도 라이브러리 목록(pom.xml)이 같으면 캐시를 재사용해 빌드 속도 향상
COPY .mvn/ .mvn
COPY mvnw pom.xml ./

# 2. Windows에서 작업 시 생기는 줄바꿈 문자(\r)를 리눅스용으로 변환 후 실행 권한 부여 및 의존성 다운로드
RUN sed -i 's/\r$//' mvnw && chmod +x mvnw && ./mvnw dependency:go-offline

# 3. 실제 Java 백엔드 소스 코드 복사 후 JAR 파일 패키징 (빌드 시간 단축을 위해 단위 테스트 생략)
COPY src ./src
RUN ./mvnw clean package -DskipTests


# ==============================================================================
# [2단계: 실행 스테이지 (Runtime)]
# 빌드에 쓴 무거운 JDK와 소스는 버리고, 실행 전용 경량 Java 21 JRE(noble)만 사용
# ==============================================================================
FROM eclipse-temurin:21-jre-noble

# 컨테이너 내부 작업 디렉터리 설정
WORKDIR /app

# 1단계(builder)에서 생성된 실행용 JAR 파일만 복사하여 app.jar로 이름 통일
COPY --from=builder /app/target/*.jar app.jar

# Spring PetClinic REST 백엔드 기본 통신 포트(9966) 명시
EXPOSE 9966

# 컨테이너 시작 시 Java 애플리케이션 실행
# -> DB 주소와 비밀번호는 이미지에 굽지 않고 컨테이너 실행 시 외부 환경변수로 주입함
ENTRYPOINT ["java", "-jar", "app.jar"]