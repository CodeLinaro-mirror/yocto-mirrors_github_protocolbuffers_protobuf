package com.google.protobuf;

import java.io.IOException;
import java.util.Iterator;
import java.util.Map.Entry;

/**
 * InternalLazyField encapsulates the logic of lazily parsing message fields. It stores the message
 * in a ByteString initially and then parses it on-demand.
 *
 * <p>The invariants of InternalLazyField are that 1) once value or bytes is set, they will not be
 * changed; 2) value and bytes cannot be null at the same time; 3) If corrupted is true, value must
 * be null.
 */
class InternalLazyField {

  // Each lazy field must have a default instance of the message type, which is used to parse the
  // bytes.
  private final MessageLite defaultInstance;

  // The extension registry for this lazy field to parse the bytes.
  private final ExtensionRegistryLite extensionRegistry;

  // The bytes for this lazy field. It can represent the unparsed bytes or the memoized bytes of the
  // serialized message.
  private volatile ByteString bytes;

  // The parsed message value.
  protected volatile MessageLite value;

  // Whether the lazy field (i.e. {@link bytes}) was corrupted, and if so, {@link value} must be
  // `null`.
  private volatile boolean corrupted;

  /** Constructor for InternalLazyField. All arguments cannot be null. */
  InternalLazyField(
      MessageLite defaultInstance, ExtensionRegistryLite extensionRegistry, ByteString bytes) {
    if (defaultInstance == null) {
      throw new IllegalArgumentException("defaultInstance cannot be null");
    }
    if (extensionRegistry == null) {
      throw new IllegalArgumentException("extensionRegistry cannot be null");
    }
    if (bytes == null) {
      throw new IllegalArgumentException("bytes cannot be null");
    }
    this.defaultInstance = defaultInstance;
    this.extensionRegistry = extensionRegistry;
    this.bytes = bytes;
    this.corrupted = false;
    this.value = null;
  }

  /**
   * Constructor for InternalLazyField that takes in a message value. The argument cannot be null.
   */
  InternalLazyField(MessageLite message) {
    if (message == null) {
      throw new IllegalArgumentException("message cannot be null");
    }
    this.value = message;
    this.defaultInstance = message.getDefaultInstanceForType();
    this.extensionRegistry = ExtensionRegistryLite.getEmptyRegistry();
    this.bytes = null;
    this.corrupted = false;
  }

  /**
   * Merges the InternalLazyField from the given CodedInputStream with the given extension registry.
   *
   * <p>Precondition: the input stream should have already read the tag and be expected to read the
   * size of the bytes next.
   *
   * @throws IOException only if an error occurs while reading the raw bytes from the input stream,
   *     not for failures in parsing the read bytes.
   * @throws InvalidProtobufRuntimeException if the lazy field is corrupted and cannot be merged
   *     with a different extension registry.
   */
  static InternalLazyField mergeFrom(
      InternalLazyField lazyField, CodedInputStream input, ExtensionRegistryLite extensionRegistry)
      throws IOException {
    ByteString inputBytes = input.readBytes();
    if (lazyField.isEmpty()) {
      return new InternalLazyField(lazyField.defaultInstance, extensionRegistry, inputBytes);
    }

    if (lazyField.hasBytes()) {
      if (lazyField.extensionRegistry == extensionRegistry) {
        return new InternalLazyField(
            lazyField.defaultInstance, extensionRegistry, lazyField.bytes.concat(inputBytes));
      }
      // The extension registries are different, so we need to parse the bytes first to "consume"
      // the extension registry of this lazy field.
      lazyField.initializeValue(/* atMerge= */ true);

      // If the lazy field is corrupted, instead of holding and concatenating the bytes, just
      // throw an exception, as we cannot resolve two different extension registries.
      if (lazyField.corrupted) {
        throw new InvalidProtobufRuntimeException(
            "Cannot merge invalid lazy field from bytes that is absent or with a different"
                + " extension registry.");
      }
    }

    return mergaValueFromBytes(lazyField, inputBytes, extensionRegistry);
  }

  /**
   * Merges a InternalLazyField from another InternalLazyField.
   *
   * @throws InvalidProtobufRuntimeException if either lazy field is corrupted and cannot be merged
   *     with a different extension registry.
   */
  static InternalLazyField mergeFrom(InternalLazyField self, InternalLazyField other) {
    if (self.defaultInstance != other.defaultInstance) {
      throw new IllegalArgumentException(
          "LazyFields with different default instances cannot be merged.");
    }

    // If either InternalLazyField is empty, return the other InternalLazyField.
    if (self.isEmpty()) {
      return other;
    }
    if (other.isEmpty()) {
      return self;
    }

    // Fast path: concatenate the bytes if both LazyFields contain bytes and have the same extension
    // registry, even if one or both are corrupted.
    if (self.hasBytes() && other.hasBytes() && self.extensionRegistry == other.extensionRegistry) {
      return new InternalLazyField(
          self.defaultInstance, self.extensionRegistry, self.bytes.concat(other.bytes));
    }

    // Cannot concatenate the bytes right way. Try initializing the value first and merge from
    // the other.
    self.initializeValue(/* atMerge= */ true);
    if (self.corrupted) {
      // The self lazy field is corrupted, meaning that it contains invalid bytes to be
      // concatenated. However, we should only do so if other has bytes and the extension registries
      // are the same. Which has already been handled above.
      throw new InvalidProtobufRuntimeException(
          "Cannot merge invalid lazy field from bytes that is absent or with a different"
              + " extension registry.");
    }

    // Merge from the other depending on whether the other contains bytes or value.
    if (other.value != null) {
      return new InternalLazyField(self.value.toBuilder().mergeFrom(other.value).build());
    }

    // Since other.value is null, other.bytes must be non-null.
    return mergaValueFromBytes(self, other.bytes, other.extensionRegistry);
  }

  /**
   * Merges the InternalLazyField from the given ByteString with the given extension registry.
   *
   * <p>It can throw a runtime exception if it cannot parse the bytes.
   */
  private static InternalLazyField mergaValueFromBytes(
      InternalLazyField self, ByteString inputBytes, ExtensionRegistryLite extensionRegistry) {
    try {
      return new InternalLazyField(
          self.value.toBuilder().mergeFrom(inputBytes, extensionRegistry).build());
    } catch (InvalidProtocolBufferException e) {
      // If the input bytes is corrupted, we should cancat bytes. However, we should only do so if
      // the extension registries are the same AND self.bytes is present. This should have been
      // handled in the mergeFrom function, so we just throw an exception here.
      throw new InvalidProtobufRuntimeException(
          "Cannot merge lazy field from invalid bytes with a different extension registry.", e);
    }
  }

  private boolean hasBytes() {
    return bytes != null;
  }

  private boolean isEmpty() {
    if (bytes == null) {
      return value == null || value.equals(defaultInstance);
    }
    return bytes.isEmpty();
  }

  private void initializeValue(boolean atMerge) {
    if (value != null) {
      return;
    }

    synchronized (this) {
      if (corrupted) {
        if (atMerge || !ExtensionRegistryLite.lazyExtensionEnabled()) {
          return;
        }
        // It's unnecessary to throw exception here as it is unreachable. initializaValue can only
        // be re-visited after a merge, but during the merge an exception has already been thrown
        // for corrupted lazy fields or there was no need to initialize the value (i.e. concatenate
        // bytes).
      }
      try {
        if (hasBytes()) {
          value = defaultInstance.getParserForType().parseFrom(bytes, extensionRegistry);
        } else {
          value = defaultInstance;
        }
      } catch (InvalidProtocolBufferException e) {
        if (atMerge || !ExtensionRegistryLite.lazyExtensionEnabled()) {
          corrupted = true;
          value = null;
          return;
        }
        throw new InvalidProtobufRuntimeException(e);
      }
    }
  }

  MessageLite getValue() {
    initializeValue(/* atMerge= */ false);
    return value == null ? defaultInstance : value;
  }

  int getSerializedSize() {
    if (bytes != null) {
      return bytes.size();
    }
    return value.getSerializedSize();
  }

  ByteString toByteString() {
    if (bytes != null) {
      return bytes;
    }
    synchronized (this) {
      if (bytes != null) {
        return bytes;
      }
      bytes = value.toByteString();
      return bytes;
    }
  }

  int computeSizeNoTag() {
    return CodedOutputStream.computeLengthDelimitedFieldSize(getSerializedSize());
  }

  int computeSize(final int fieldNumber) {
    return CodedOutputStream.computeTagSize(fieldNumber) + computeSizeNoTag();
  }

  int computeMessageSetExtensionSize(final int fieldNumber) {
    return CodedOutputStream.computeTagSize(WireFormat.MESSAGE_SET_ITEM) * 2
        + CodedOutputStream.computeUInt32Size(WireFormat.MESSAGE_SET_TYPE_ID, fieldNumber)
        + computeSize(WireFormat.MESSAGE_SET_MESSAGE);
  }

  void writeTo(Writer writer, int fieldNumber) throws IOException {
    if (bytes != null) {
      writer.writeBytes(fieldNumber, bytes);
    } else {
      writer.writeMessage(fieldNumber, value);
    }
  }

  @Override
  public int hashCode() {
    return getValue().hashCode();
  }

  @Override
  public boolean equals(
          Object obj) {
    return getValue().equals(obj);
  }

  @Override
  @SuppressWarnings("LiteProtoToString") // Keep the old behavior of toString().
  public String toString() {
    return getValue().toString();
  }

  /**
   * LazyEntry and LazyIterator are used to encapsulate the lazy field, when users iterate all
   * fields from FieldSet.
   */
  static class LazyEntry<K> implements Entry<K, Object> {
    private final Entry<K, InternalLazyField> entry;

    private LazyEntry(Entry<K, InternalLazyField> entry) {
      this.entry = entry;
    }

    @Override
    public K getKey() {
      return entry.getKey();
    }

    @Override
    public Object getValue() {
      InternalLazyField field = entry.getValue();
      if (field == null) {
        return null;
      }
      return field.getValue();
    }

    public InternalLazyField getField() {
      return entry.getValue();
    }

    @Override
    @SuppressWarnings("PatternMatchingInstanceof")
    public Object setValue(Object value) {
      if (!(value instanceof MessageLite)) {
        throw new IllegalArgumentException("Lazy field only supports MessageLite values.");
      }
      // No need to initialize the value.
      // TODO: b/473034710 - This may be weird as it can return null. Consider returning the parsed
      // value or the lazy field directly as it's only facing internal usage.
      Object oldValue = entry.getValue().value;
      entry.setValue(new InternalLazyField((MessageLite) value));
      return oldValue;
    }
  }

  static class LazyIterator<K> implements Iterator<Entry<K, Object>> {
    private Iterator<Entry<K, Object>> iterator;

    public LazyIterator(Iterator<Entry<K, Object>> iterator) {
      this.iterator = iterator;
    }

    @Override
    public boolean hasNext() {
      return iterator.hasNext();
    }

    @Override
    @SuppressWarnings("unchecked")
    public Entry<K, Object> next() {
      Entry<K, ?> entry = iterator.next();
      if (entry.getValue() instanceof InternalLazyField) {
        return new LazyEntry<K>((Entry<K, InternalLazyField>) entry);
      }
      return (Entry<K, Object>) entry;
    }

    @Override
    public void remove() {
      iterator.remove();
    }
  }
}
