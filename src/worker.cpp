#include <hiredis/hiredis.h>
#include <string>
#include <thread>
#include <iostream>
#include <chrono>
#include <memory>
#include <stdexcept>
#include <nlohmann/json.hpp>

// static const string DEFAULT_PAYMENT_URL = "http://localhost:8080/payments";
// static const string FALLBACK_PAYMENT_URL = "http://localhost:8081/payments";

class health_check_config
{
public:
    health_check_config(string url_pat)
        : url_path(url_pat) {}
    string url_path;
    bool isHealthy;
};

class redisConnection
{
private:
    static constexpr int REDIS_PORT_CONNECTION = 6379;
    static constexpr struct timeval TIMEOUT = {1, 0}; // 1 segundo de timeout
    unique_ptr<redisContext, decltype(&redisFree)> context{nullptr, redisFree};
    void checkConnection() const
    {
        if (!context)
        {
            throw std::runtime_error("Failed to allocate Redis context");
        }
        if (context->err)
        {
            throw std::runtime_error("Error connecting to Redis: " + std::string(context->errstr));
        }
    }

public:
    redisConnection()
    {
        context.reset(redisConnect("127.0.0.1", REDIS_PORT_CONNECTION));
        redisSetTimeout(context.get(), TIMEOUT);
        checkConnection();
    }

    bool isConnected() const
    {
        return context != nullptr && context->err == 0;
    }
    void reconnect()
    {
        context.reset(redisConnect("127.0.0.1", REDIS_PORT_CONNECTION));
        redisSetTimeout(context.get(), TIMEOUT);
        checkConnection();
    }
};

int main()
{
    // redisConnection redis;

    std::cout << "init";
    return 0;
}