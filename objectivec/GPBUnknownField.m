// Protocol Buffers - Google's data interchange format
// Copyright 2008 Google Inc.  All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file or at
// https://developers.google.com/open-source/licenses/bsd

#import "GPBUnknownField.h"
#import "GPBUnknownField_PackagePrivate.h"

#import "GPBArray.h"
#import "GPBCodedOutputStream_PackagePrivate.h"
#import "GPBUnknownFieldSet.h"

#define ASSERT_FIELD_TYPE(type)                               \
  if (type_ != type) {                                        \
    [NSException raise:NSInternalInconsistencyException       \
                format:@"GPBUnknownField is the wrong type"]; \
  }

@implementation GPBUnknownField {
 @protected
  int32_t number_;
  GPBUnknownFieldType type_;

  union {
    uint64_t intValue;        // type == Varint, Fixed32, Fixed64
    NSData *lengthDelimited;  // type == LengthDelimited
    GPBUnknownFields *group;  // type == Group
    struct {                  // type == Legacy
      GPBUInt64Array *mutableVarintList;
      GPBUInt32Array *mutableFixed32List;
      GPBUInt64Array *mutableFixed64List;
      NSMutableArray<NSData *> *mutableLengthDelimitedList;
      NSMutableArray<GPBUnknownFieldSet *> *mutableGroupList;
    } legacy;
  } u_;
}

@synthesize number = number_;
@synthesize type = type_;

- (instancetype)initWithNumber:(int32_t)number {
  if ((self = [super init])) {
    number_ = number;
    type_ = GPBUnknownFieldTypeLegacy;
  }
  return self;
}

- (instancetype)initWithNumber:(int32_t)number varint:(uint64_t)varint {
  if ((self = [super init])) {
    number_ = number;
    type_ = GPBUnknownFieldTypeVarint;
    u_.intValue = varint;
  }
  return self;
}

- (instancetype)initWithNumber:(int32_t)number fixed32:(uint32_t)fixed32 {
  if ((self = [super init])) {
    number_ = number;
    type_ = GPBUnknownFieldTypeFixed32;
    u_.intValue = fixed32;
  }
  return self;
}

- (instancetype)initWithNumber:(int32_t)number fixed64:(uint64_t)fixed64 {
  if ((self = [super init])) {
    number_ = number;
    type_ = GPBUnknownFieldTypeFixed64;
    u_.intValue = fixed64;
  }
  return self;
}

- (instancetype)initWithNumber:(int32_t)number lengthDelimited:(nonnull NSData *)data {
  if ((self = [super init])) {
    number_ = number;
    type_ = GPBUnknownFieldTypeLengthDelimited;
    u_.lengthDelimited = [data copy];
  }
  return self;
}

- (instancetype)initWithNumber:(int32_t)number group:(nonnull GPBUnknownFields *)group {
  if ((self = [super init])) {
    number_ = number;
    type_ = GPBUnknownFieldTypeGroup;
    u_.group = [group retain];
  }
  return self;
}

- (void)dealloc {
  switch (type_) {
    case GPBUnknownFieldTypeVarint:
    case GPBUnknownFieldTypeFixed32:
    case GPBUnknownFieldTypeFixed64:
      break;
    case GPBUnknownFieldTypeLengthDelimited:
      [u_.lengthDelimited release];
      break;
    case GPBUnknownFieldTypeGroup:
      [u_.group release];
      break;
    case GPBUnknownFieldTypeLegacy:
      [u_.legacy.mutableVarintList release];
      [u_.legacy.mutableFixed32List release];
      [u_.legacy.mutableFixed64List release];
      [u_.legacy.mutableLengthDelimitedList release];
      [u_.legacy.mutableGroupList release];
      break;
  }

  [super dealloc];
}

// Direct access is use for speed, to avoid even internally declaring things
// read/write, etc. The warning is enabled in the project to ensure code calling
// protos can turn on -Wdirect-ivar-access without issues.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdirect-ivar-access"

- (uint64_t)varint {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeVarint);
  return u_.intValue;
}

- (uint32_t)fixed32 {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeFixed32);
  return (uint32_t)u_.intValue;
}

- (uint64_t)fixed64 {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeFixed64);
  return u_.intValue;
}

- (NSData *)lengthDelimited {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLengthDelimited);
  return u_.lengthDelimited;
}

- (GPBUnknownFields *)group {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeGroup);
  return u_.group;
}

- (GPBUInt64Array *)varintList {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  return u_.legacy.mutableVarintList;
}

- (GPBUInt32Array *)fixed32List {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  return u_.legacy.mutableFixed32List;
}

- (GPBUInt64Array *)fixed64List {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  return u_.legacy.mutableFixed64List;
}

- (NSArray<NSData *> *)lengthDelimitedList {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  return u_.legacy.mutableLengthDelimitedList;
}

- (NSArray<GPBUnknownFieldSet *> *)groupList {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  return u_.legacy.mutableGroupList;
}

- (id)copyWithZone:(NSZone *)zone {
  switch (type_) {
    case GPBUnknownFieldTypeVarint:
      return [[GPBUnknownField allocWithZone:zone] initWithNumber:number_ varint:u_.intValue];
    case GPBUnknownFieldTypeFixed32:
      return [[GPBUnknownField allocWithZone:zone] initWithNumber:number_
                                                          fixed32:(uint32_t)u_.intValue];
    case GPBUnknownFieldTypeFixed64:
      return [[GPBUnknownField allocWithZone:zone] initWithNumber:number_ fixed64:u_.intValue];
    case GPBUnknownFieldTypeLengthDelimited:
      return [[GPBUnknownField allocWithZone:zone]
           initWithNumber:number_
          lengthDelimited:[u_.lengthDelimited copyWithZone:zone]];
    case GPBUnknownFieldTypeGroup:
      return [[GPBUnknownField allocWithZone:zone] initWithNumber:number_
                                                            group:[u_.group copyWithZone:zone]];
    case GPBUnknownFieldTypeLegacy: {
      GPBUnknownField *result = [[GPBUnknownField allocWithZone:zone] initWithNumber:number_];
      result->u_.legacy.mutableFixed32List = [u_.legacy.mutableFixed32List copyWithZone:zone];
      result->u_.legacy.mutableFixed64List = [u_.legacy.mutableFixed64List copyWithZone:zone];
      result->u_.legacy.mutableLengthDelimitedList =
          [u_.legacy.mutableLengthDelimitedList mutableCopyWithZone:zone];
      result->u_.legacy.mutableVarintList = [u_.legacy.mutableVarintList copyWithZone:zone];
      if (u_.legacy.mutableGroupList.count) {
        result->u_.legacy.mutableGroupList =
            [[NSMutableArray allocWithZone:zone] initWithCapacity:u_.legacy.mutableGroupList.count];
        for (GPBUnknownFieldSet *group in u_.legacy.mutableGroupList) {
          GPBUnknownFieldSet *copied = [group copyWithZone:zone];
          [result->u_.legacy.mutableGroupList addObject:copied];
          [copied release];
        }
      }
      return result;
    }
  }
}

- (BOOL)isEqual:(id)object {
  if (self == object) return YES;
  if (![object isKindOfClass:[GPBUnknownField class]]) return NO;
  GPBUnknownField *field = (GPBUnknownField *)object;
  if (number_ != field->number_) return NO;
  if (type_ != field->type_) return NO;
  switch (type_) {
    case GPBUnknownFieldTypeVarint:
    case GPBUnknownFieldTypeFixed32:
    case GPBUnknownFieldTypeFixed64:
      return u_.intValue == field->u_.intValue;
    case GPBUnknownFieldTypeLengthDelimited:
      return [u_.lengthDelimited isEqual:field->u_.lengthDelimited];
    case GPBUnknownFieldTypeGroup:
      return [u_.group isEqual:field->u_.group];
    case GPBUnknownFieldTypeLegacy: {
      BOOL equalVarint = (u_.legacy.mutableVarintList.count == 0 &&
                          field->u_.legacy.mutableVarintList.count == 0) ||
                         [u_.legacy.mutableVarintList isEqual:field->u_.legacy.mutableVarintList];
      if (!equalVarint) return NO;
      BOOL equalFixed32 =
          (u_.legacy.mutableFixed32List.count == 0 &&
           field->u_.legacy.mutableFixed32List.count == 0) ||
          [u_.legacy.mutableFixed32List isEqual:field->u_.legacy.mutableFixed32List];
      if (!equalFixed32) return NO;
      BOOL equalFixed64 =
          (u_.legacy.mutableFixed64List.count == 0 &&
           field->u_.legacy.mutableFixed64List.count == 0) ||
          [u_.legacy.mutableFixed64List isEqual:field->u_.legacy.mutableFixed64List];
      if (!equalFixed64) return NO;
      BOOL equalLDList = (u_.legacy.mutableLengthDelimitedList.count == 0 &&
                          field->u_.legacy.mutableLengthDelimitedList.count == 0) ||
                         [u_.legacy.mutableLengthDelimitedList
                             isEqual:field->u_.legacy.mutableLengthDelimitedList];
      if (!equalLDList) return NO;
      BOOL equalGroupList =
          (u_.legacy.mutableGroupList.count == 0 && field->u_.legacy.mutableGroupList.count == 0) ||
          [u_.legacy.mutableGroupList isEqual:field->u_.legacy.mutableGroupList];
      if (!equalGroupList) return NO;
      return YES;
    }
  }
}

- (NSUInteger)hash {
  const int prime = 31;
  NSUInteger result = prime * number_ + type_;
  switch (type_) {
    case GPBUnknownFieldTypeVarint:
    case GPBUnknownFieldTypeFixed32:
    case GPBUnknownFieldTypeFixed64:
      result = prime * result + (NSUInteger)u_.intValue;
      break;
    case GPBUnknownFieldTypeLengthDelimited:
      result = prime * result + [u_.lengthDelimited hash];
      break;
    case GPBUnknownFieldTypeGroup:
      result = prime * result + [u_.group hash];
    case GPBUnknownFieldTypeLegacy:
      result = prime * result + [u_.legacy.mutableVarintList hash];
      result = prime * result + [u_.legacy.mutableFixed32List hash];
      result = prime * result + [u_.legacy.mutableFixed64List hash];
      result = prime * result + [u_.legacy.mutableLengthDelimitedList hash];
      result = prime * result + [u_.legacy.mutableGroupList hash];
      break;
  }
  return result;
}

- (void)writeToOutput:(GPBCodedOutputStream *)output {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  NSUInteger count = u_.legacy.mutableVarintList.count;
  if (count > 0) {
    [output writeUInt64Array:number_ values:u_.legacy.mutableVarintList tag:0];
  }
  count = u_.legacy.mutableFixed32List.count;
  if (count > 0) {
    [output writeFixed32Array:number_ values:u_.legacy.mutableFixed32List tag:0];
  }
  count = u_.legacy.mutableFixed64List.count;
  if (count > 0) {
    [output writeFixed64Array:number_ values:u_.legacy.mutableFixed64List tag:0];
  }
  count = u_.legacy.mutableLengthDelimitedList.count;
  if (count > 0) {
    [output writeBytesArray:number_ values:u_.legacy.mutableLengthDelimitedList];
  }
  count = u_.legacy.mutableGroupList.count;
  if (count > 0) {
    [output writeUnknownGroupArray:number_ values:u_.legacy.mutableGroupList];
  }
}

- (size_t)serializedSize {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  __block size_t result = 0;
  int32_t number = number_;
  [u_.legacy.mutableVarintList
      enumerateValuesWithBlock:^(uint64_t value, __unused NSUInteger idx, __unused BOOL *stop) {
        result += GPBComputeUInt64Size(number, value);
      }];

  [u_.legacy.mutableFixed32List
      enumerateValuesWithBlock:^(uint32_t value, __unused NSUInteger idx, __unused BOOL *stop) {
        result += GPBComputeFixed32Size(number, value);
      }];

  [u_.legacy.mutableFixed64List
      enumerateValuesWithBlock:^(uint64_t value, __unused NSUInteger idx, __unused BOOL *stop) {
        result += GPBComputeFixed64Size(number, value);
      }];

  for (NSData *data in u_.legacy.mutableLengthDelimitedList) {
    result += GPBComputeBytesSize(number, data);
  }

  for (GPBUnknownFieldSet *set in u_.legacy.mutableGroupList) {
    result += GPBComputeUnknownGroupSize(number, set);
  }

  return result;
}

- (void)writeAsMessageSetExtensionToOutput:(GPBCodedOutputStream *)output {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  for (NSData *data in u_.legacy.mutableLengthDelimitedList) {
    [output writeRawMessageSetExtension:number_ value:data];
  }
}

- (size_t)serializedSizeAsMessageSetExtension {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  size_t result = 0;
  for (NSData *data in u_.legacy.mutableLengthDelimitedList) {
    result += GPBComputeRawMessageSetExtensionSize(number_, data);
  }
  return result;
}

- (NSString *)description {
  NSMutableString *description =
      [NSMutableString stringWithFormat:@"<%@ %p>: Field: %d", [self class], self, number_];
  switch (type_) {
    case GPBUnknownFieldTypeVarint:
      [description appendFormat:@" varint: %llu", u_.intValue];
      break;
    case GPBUnknownFieldTypeFixed32:
      [description appendFormat:@" fixed32: %u", (uint32_t)u_.intValue];
      break;
    case GPBUnknownFieldTypeFixed64:
      [description appendFormat:@" fixed64: %llu", u_.intValue];
      break;
    case GPBUnknownFieldTypeLengthDelimited:
      [description appendFormat:@" fixed64: %@", u_.lengthDelimited];
      break;
    case GPBUnknownFieldTypeGroup:
      [description appendFormat:@" group: %@", u_.group];
      break;
    case GPBUnknownFieldTypeLegacy:
      [description appendString:@" {\n"];
      [u_.legacy.mutableVarintList
          enumerateValuesWithBlock:^(uint64_t value, __unused NSUInteger idx, __unused BOOL *stop) {
            [description appendFormat:@"\t%llu\n", value];
          }];
      [u_.legacy.mutableFixed32List
          enumerateValuesWithBlock:^(uint32_t value, __unused NSUInteger idx, __unused BOOL *stop) {
            [description appendFormat:@"\t%u\n", value];
          }];
      [u_.legacy.mutableFixed64List
          enumerateValuesWithBlock:^(uint64_t value, __unused NSUInteger idx, __unused BOOL *stop) {
            [description appendFormat:@"\t%llu\n", value];
          }];
      for (NSData *data in u_.legacy.mutableLengthDelimitedList) {
        [description appendFormat:@"\t%@\n", data];
      }
      for (GPBUnknownFieldSet *set in u_.legacy.mutableGroupList) {
        [description appendFormat:@"\t%@\n", set];
      }
      [description appendString:@"}"];
      break;
  }
  return description;
}

- (void)mergeFromField:(GPBUnknownField *)other {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  GPBUInt64Array *otherVarintList = other.varintList;
  if (otherVarintList.count > 0) {
    if (u_.legacy.mutableVarintList == nil) {
      u_.legacy.mutableVarintList = [otherVarintList copy];
    } else {
      [u_.legacy.mutableVarintList addValuesFromArray:otherVarintList];
    }
  }

  GPBUInt32Array *otherFixed32List = other.fixed32List;
  if (otherFixed32List.count > 0) {
    if (u_.legacy.mutableFixed32List == nil) {
      u_.legacy.mutableFixed32List = [otherFixed32List copy];
    } else {
      [u_.legacy.mutableFixed32List addValuesFromArray:otherFixed32List];
    }
  }

  GPBUInt64Array *otherFixed64List = other.fixed64List;
  if (otherFixed64List.count > 0) {
    if (u_.legacy.mutableFixed64List == nil) {
      u_.legacy.mutableFixed64List = [otherFixed64List copy];
    } else {
      [u_.legacy.mutableFixed64List addValuesFromArray:otherFixed64List];
    }
  }

  NSArray *otherLengthDelimitedList = other.lengthDelimitedList;
  if (otherLengthDelimitedList.count > 0) {
    if (u_.legacy.mutableLengthDelimitedList == nil) {
      u_.legacy.mutableLengthDelimitedList = [otherLengthDelimitedList mutableCopy];
    } else {
      [u_.legacy.mutableLengthDelimitedList addObjectsFromArray:otherLengthDelimitedList];
    }
  }

  NSArray *otherGroupList = other.groupList;
  if (otherGroupList.count > 0) {
    if (u_.legacy.mutableGroupList == nil) {
      u_.legacy.mutableGroupList = [[NSMutableArray alloc] initWithCapacity:otherGroupList.count];
    }
    // Make our own mutable copies.
    for (GPBUnknownFieldSet *group in otherGroupList) {
      GPBUnknownFieldSet *copied = [group copy];
      [u_.legacy.mutableGroupList addObject:copied];
      [copied release];
    }
  }
}

- (void)addVarint:(uint64_t)value {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  if (u_.legacy.mutableVarintList == nil) {
    u_.legacy.mutableVarintList = [[GPBUInt64Array alloc] initWithValues:&value count:1];
  } else {
    [u_.legacy.mutableVarintList addValue:value];
  }
}

- (void)addFixed32:(uint32_t)value {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  if (u_.legacy.mutableFixed32List == nil) {
    u_.legacy.mutableFixed32List = [[GPBUInt32Array alloc] initWithValues:&value count:1];
  } else {
    [u_.legacy.mutableFixed32List addValue:value];
  }
}

- (void)addFixed64:(uint64_t)value {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  if (u_.legacy.mutableFixed64List == nil) {
    u_.legacy.mutableFixed64List = [[GPBUInt64Array alloc] initWithValues:&value count:1];
  } else {
    [u_.legacy.mutableFixed64List addValue:value];
  }
}

- (void)addLengthDelimited:(NSData *)value {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  if (u_.legacy.mutableLengthDelimitedList == nil) {
    u_.legacy.mutableLengthDelimitedList = [[NSMutableArray alloc] initWithObjects:&value count:1];
  } else {
    [u_.legacy.mutableLengthDelimitedList addObject:value];
  }
}

- (void)addGroup:(GPBUnknownFieldSet *)value {
  ASSERT_FIELD_TYPE(GPBUnknownFieldTypeLegacy);
  if (u_.legacy.mutableGroupList == nil) {
    u_.legacy.mutableGroupList = [[NSMutableArray alloc] initWithObjects:&value count:1];
  } else {
    [u_.legacy.mutableGroupList addObject:value];
  }
}

#pragma clang diagnostic pop

@end
