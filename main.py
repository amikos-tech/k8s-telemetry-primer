import uvicorn
from fastapi import FastAPI
import requests
app = FastAPI()

class SomeService():
    def __init__(self):
        self.dao = DAOService()

    def increment(self):
        self.dao.increment()

    def get_counter(self):
        return self.dao.get_counter()
    
class DAOService():
    def __init__(self):
        self._counter = 0

    def increment(self):
        self._counter += 1

    def get_counter(self):
        return self._counter

service = SomeService()

@app.get('/')
def index():
    service.increment()
    resp=requests.get('https://google.com')
    return {'message': f'Hello, World {service.get_counter()}!'}




if __name__ == '__main__':
    uvicorn.run(app, host="0.0.0.0", port=8000)