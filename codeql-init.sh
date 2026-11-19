codeql database create security-db \
    --language=c-cpp \
    --command="make -B -j4"

codeql database analyze security-db \
    codeql/cpp-queries \
    --format=sarif-latest \
    --output=security.sarif
