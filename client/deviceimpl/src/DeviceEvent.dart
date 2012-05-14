//Copyright (C) 2012 Potix Corporation. All Rights Reserved.
//History: Thu, May 3, 2012  10:48:26 AM
// Author: henrichen

/**
 * Event fired from the device.
 */
class DeviceEvent {
	/** Returns whether this event's propagation is stopped.
	 * <p>Default: false.
	 * <p>It becomes true if {@link #stopPropagation} is called,
	 * and then all remaining event listeners are ignored.
	 */
	bool get propagationStopped() => _propStop;
	/** Stops the propagation.
	 *Once called, all remaining event listeners, if any, are ignored.
	 */
	void stopPropagation() {
		_propStop = true;
	}
}
