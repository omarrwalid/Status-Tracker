# Build context = this folder (Server/).  docker build -t clausetracker-server .
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ClauseTracker.Server.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app .
# Hosts inject DATABASE_URL (and SETUP_KEY) as environment variables.
# Hugging Face Spaces expects the app on port 7860 (other hosts override PORT themselves).
ENV ASPNETCORE_ENVIRONMENT=Production PORT=7860
EXPOSE 7860
# Spaces run containers as user 1000.
USER 1000
ENTRYPOINT ["dotnet", "ClauseTracker.Server.dll"]
