console.time(PKG.name);

angular
  .module(PKG.name, [

    PKG.name+'.features',

    angular.module(PKG.name+'.services', [
      PKG.name+'.config',
      'ngResource',
      'ngStorage'
    ]).name,

    angular.module(PKG.name+'.filters', [
      PKG.name+'.services'
    ]).name,

    angular.module(PKG.name+'.directives', [
      PKG.name+'.services',
      PKG.name+'.filters',
      'mgcrea.ngStrap.alert',
      'mgcrea.ngStrap.tooltip',
      'mgcrea.ngStrap.popover',
      'mgcrea.ngStrap.dropdown',
      'mgcrea.ngStrap.collapse',
      'mgcrea.ngStrap.button',
      'mgcrea.ngStrap.tab',
      'mgcrea.ngStrap.modal'
    ]).name,

    'angular-loading-bar',
    'angularMoment',
    'ngAnimate',
    'ngSanitize',
    'ui.router'
  ])

  .run(function ($rootScope, $state, $stateParams) {
    // It's very handy to add references to $state and $stateParams to the $rootScope
    // so that you can access them from any scope within your applications.For example,
    // <li ng-class="{ active: $state.includes('contacts.list') }"> will set the <li>
    // to active whenever 'contacts.list' or one of its decendents is active.
    $rootScope.$state = $state;
    $rootScope.$stateParams = $stateParams;
  })


  .config(function ($locationProvider) {
    $locationProvider.html5Mode(true);
  })


  .config(function ($httpProvider) {

    $httpProvider.interceptors.push(function () {
      return {
        request: function(config) {
          config.timeout = 3000; // 3 seconds default
          return config;
        }
      };
    });

    var delay = window.location.search.match(/delay=(\d+)/);
    if(delay) {
      delay = parseInt(delay[1], 10);
      console.log('HTTP interceptor will delay responses for', delay, 'ms');
      $httpProvider.interceptors.push(function ($q, $timeout) {
        return {
          response: function(data) {
            var defer = $q.defer();
            $timeout(function () {
              defer.resolve(data);
            }, delay);
            return defer.promise;
          }
        };
      });
    }
  })


  .config(function ($alertProvider) {
    angular.extend($alertProvider.defaults, {
      animation: 'am-fade-and-scale',
      container: '#alerts > .container',
      duration: 3
    });

    // speed up integration tests
    if(window.name==='PROTRACTOR') {
      $alertProvider.defaults.duration = false;
    }
  })

  .config(function ($compileProvider) {
    $compileProvider.aHrefSanitizationWhitelist(
      /^\s*(https?|ftp|mailto|tel|file|blob):/
    );
  })

  .config(function (cfpLoadingBarProvider) {
    cfpLoadingBarProvider.includeSpinner = false;
  })


  .run(function ($rootScope, $alert, MYAPI_EVENT) {
    $rootScope.$on(MYAPI_EVENT.error, function (event, rejection) {
      $alert({
        title: 'API error '+rejection.status,
        content: rejection.data || 'could not connect to the server',
        type: 'danger'
      });
    });
  })


  /**
   * BodyCtrl
   * attached to the <body> tag, mostly responsible for
   *  setting the className based events from $state and myTheme
   */
  .controller('BodyCtrl', function ($scope, myTheme, MYTHEME_EVENT) {

    var activeThemeClass = myTheme.getClassName();


    $scope.$on(MYTHEME_EVENT.changed, function (event, newClassName) {
      if(!event.defaultPrevented) {
        $scope.bodyClass = $scope.bodyClass.replace(activeThemeClass, newClassName);
        activeThemeClass = newClassName;
      }
    });


    $scope.$on('$stateChangeSuccess', function (event, state) {
      var classes = [];
      if(state.data && state.data.bodyClass) {
        classes = [state.data.bodyClass];
      }
      else {
        var parts = state.name.split('.'),
            count = parts.length + 1;
        while (1<count--) {
          classes.push('state-' + parts.slice(0,count).join('-'));
        }
      }

      classes.push(activeThemeClass);

      $scope.bodyClass = classes.join(' ');
    });



    console.timeEnd(PKG.name);
  });

