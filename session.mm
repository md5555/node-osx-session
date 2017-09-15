#import "Session.h"

#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include <queue>

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
 
// node headers
#include <v8.h>
#include <node.h>
#include <unistd.h>
#include <string.h>

using namespace node;
using namespace v8;

@interface SessionNotificationCallback : NSObject

- (void)startMonitor;
- (void)stopMonitor;
- (void)callbackWithNotification:(NSNotification *)myNotification;

@end

namespace Session {
    Persistent<Function> * callback = nil;
    SessionNotificationCallback * noti = nil;

    void runOnMainQueueWithoutDeadlocking(void (^block)(void)) {

	if ([NSThread isMainThread])
	{
	    block();
	}
	else
	{
	    dispatch_sync(dispatch_get_main_queue(), block);
	}
    }
}

@implementation SessionNotificationCallback

+(id)newSessionNotificationCallback {
    NSLog(@"Created Session Observer");
    return [[super alloc] init];
}

- (void)stopMonitor {

    [[[NSWorkspace sharedWorkspace] notificationCenter]
            removeObserver:self
            ];
 
    [[[NSWorkspace sharedWorkspace] notificationCenter]
            removeObserver:self
            ];
}

- (void)startMonitor {

    [[[NSWorkspace sharedWorkspace] notificationCenter]
            addObserver:self
            selector:@selector(switchHandler:)
            name:NSWorkspaceSessionDidBecomeActiveNotification
            object:nil];
 
    [[[NSWorkspace sharedWorkspace] notificationCenter]
            addObserver:self
            selector:@selector(switchHandler:)
            name:NSWorkspaceSessionDidResignActiveNotification
            object:nil];

}

- (void) switchHandler:(NSNotification*) notification {

    int state = 0;

    if ([[notification name] isEqualToString:
                NSWorkspaceSessionDidResignActiveNotification])
    {
	state = 0;
    }
    else
    {
	state = 1;
    }

    TryCatch try_catch(Isolate::GetCurrent());
 
    // prepare arguments for the callback
    Local<Value> argv[1];
    argv[0] = Integer::New(Isolate::GetCurrent(), (int)state);
 
    // call the callback and handle possible exception
    Session::callback->Get(Isolate::GetCurrent())->Call(v8::Object::New(Isolate::GetCurrent()), 1, argv);
 
    if (try_catch.HasCaught()) {
        FatalException(Isolate::GetCurrent(), try_catch);
    }
}

- (void)callbackWithNotification:(NSNotification *)myNotification {

    Session::runOnMainQueueWithoutDeadlocking(^{
	[self pushSessionState];
    });
}

@end

static void Stop(const v8::FunctionCallbackInfo<v8::Value>& args) {

    if (!Session::noti) {
	return;
    } 

    [Session::noti stopMonitor];
    Session::noti = nil;
}

static void Start(const v8::FunctionCallbackInfo<v8::Value>& args) {

    Local<Function> cb = Local<Function>::Cast(args[0]);
    Session::callback = new Persistent<Function>(Isolate::GetCurrent(), cb);

    Session::noti = [SessionNotificationCallback newSessionNotificationCallback];
    [Session::noti startMonitor];
} 

namespace SessionControlSession {
    Handle<Value> Initialize(Handle<Object> target)
    {
	target->Set(String::NewFromUtf8(Isolate::GetCurrent(), "observe"),
	    FunctionTemplate::New(Isolate::GetCurrent(), Start)->GetFunction());

	target->Set(String::NewFromUtf8(Isolate::GetCurrent(), "ignore"),
	    FunctionTemplate::New(Isolate::GetCurrent(), Stop)->GetFunction());

	return True(Isolate::GetCurrent());
    }
}

NODE_MODULE(node_osx_session, SessionControlSession::Initialize);
