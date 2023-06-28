// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#import "CUPHTTPStreamToNSInputStreamAdapter.h"

#import <Foundation/Foundation.h>
#include <os/log.h>

@implementation CUPHTTPStreamToNSInputStreamAdapter {
  Dart_Port _sendPort;
  NSCondition* _dataCondition;
  NSMutableData * _data;
  NSStreamStatus _status;
  BOOL _done;
  NSError* _error;
  id<NSStreamDelegate> _delegate;  // __weak can't be!
}

- (instancetype) initWithPort:(Dart_Port)sendPort {
  os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "PREFIX:initWithPort");
  self = [super init];
  if (self != nil) {
    _sendPort = sendPort;
    _dataCondition = [[NSCondition alloc] init];
    _data = [[NSMutableData alloc] init];
    _done = NO;
    _status = NSStreamStatusNotOpen;
    _error = nil;
    _delegate = self;
  }
  return self;
}

- (void)dealloc {
  [_dataCondition release];
  [_data release];
  [_error release];
  [super dealloc];
}

- (NSUInteger) addData:(NSData *) data {
  os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "PREFIX:addData");
  [_dataCondition lock];
  [_data appendData: data];
  [_dataCondition broadcast];
  [_dataCondition unlock];
  return [_data length];
}

// _status = NSStreamStatusError;

- (void) setDone {
  os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "PREFIX:done");
  [_dataCondition lock];
  _done = YES;
  [_dataCondition broadcast];
  [_dataCondition unlock];
}

- (void) setError:(NSError *) error {
  [_error release];
  _error = [error retain];
  _status = NSStreamStatusError;
}


#pragma mark - NSStream

- (void)scheduleInRunLoop:(NSRunLoop*)runLoop forMode:(NSString*)mode {
}

- (void)removeFromRunLoop:(NSRunLoop*)runLoop forMode:(NSString*)mode {
}

- (void)open
{
  os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "PREFIX:open");
  _status = NSStreamStatusOpen;
}

- (void)close
{
  os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "PREFIX:close");
  _status = NSStreamStatusClosed;
  Dart_CObject message_cobj;
  message_cobj.type = Dart_CObject_kNull;
  const bool success = Dart_PostCObject_DL(_sendPort, &message_cobj);
  NSCAssert(success, @"Dart_PostCObject_DL failed.");
}

- (id)propertyForKey:(NSStreamPropertyKey)key {
  return nil;
}

- (BOOL)setProperty:(id)property forKey:(NSStreamPropertyKey)key {
  return NO;
}

- (id<NSStreamDelegate>)delegate {
  return _delegate;
}

- (void)setDelegate:(id<NSStreamDelegate>)delegate {
  if (delegate == nil) {
    _delegate = self;
  } else {
    _delegate = delegate;
  }
}

- (NSError*)streamError {
  os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "PREFIX:streamError");
  return _error;
}

- (NSStreamStatus)streamStatus
{
  os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "PREFIX:streamStatus");
  return _status;
}

#pragma mark - NSInputStream

- (NSInteger)read:(uint8_t*)buffer maxLength:(NSUInteger)len {
  [_dataCondition lock];

  while ([_data length] == 0 && !_done && _error == nil) {
    Dart_CObject message_cobj;
    message_cobj.type = Dart_CObject_kInt64;
    message_cobj.value.as_int64 = len;

    const bool success = Dart_PostCObject_DL(_sendPort, &message_cobj);
    NSCAssert(success, @"Dart_PostCObject_DL failed.");

    [_dataCondition wait];
  }

  NSInteger copySize;
  if (_error == nil) {
    copySize = MIN(len, [_data length]);
    NSRange readRange = NSMakeRange(0, copySize);
    [_data getBytes:(void *)buffer range: readRange];
    [_data replaceBytesInRange: readRange withBytes: NULL length: 0];

    if (_done && [_data length] == 0) {
      _status = NSStreamStatusAtEnd;
    }
  } else {
    copySize = -1;
  }

  [_dataCondition unlock];
  return copySize;
}

- (BOOL)getBuffer:(uint8_t**)buffer length:(NSUInteger*)len {
  return NO;
}

- (BOOL)hasBytesAvailable {
  return YES;
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
  id<NSStreamDelegate> delegate = _delegate;
  if (delegate != self) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "non-self delegate was invoked");
  }
}

@end
