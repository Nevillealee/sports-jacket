# www.ellie.com api

API written in Ruby using the Sinatra framework with a postgresql database for management of customer accounts.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system. <br />
```
$ git clone git@github.com:Nevillealee/sports-jacket.git
```
cd into app directory <br />
```
$ bundle install
$ touch .env
```
set up missing enviornment variables using a search in your IDE for 'ENV' <br />
```
$ rake db:setup
```
run these taks in seperate terminal tabs: <br />
```
$ rake redis-server
$ rake resque:work QUEUE='*'
$ cd api && puma
```
*optional tunneling with ngrok for testing with postman etc* 
install [ngrok](https://ngrok.com/download)<br />
```
$ ./ngrok http 9292
```
### Prerequisites
ruby 2.4.0<br/>
bundler<br/>
postgresql libpq-dev
```
https://rvm.io/rvm/install
https://bundler.io/
*For Ubuntu systems: sudo apt-get install libpq-dev
*For Mac Homebrew: brew install postgresql
```
## Built With

* [Sinatra](http://sinatrarb.com/) - The web framework used
* [bundler](https://bundler.io/) - Dependency Management

## Authors
* **Neville Lee** - *Initial work* - [Nevillealee](https://github.com/nevillealee)
* **Floyd  Wallace** - *Initial work* - [FLWallace105](https://github.com/FLWallace105)
* **Ryan Barth** - *Initial work* - [r-bar](https://github.com/r-bar)
