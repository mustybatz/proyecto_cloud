

from locust import HttpUser, task

class HelloWorldUser(HttpUser):
    @task
    def covid_api(self):
        self.client.get("/")


