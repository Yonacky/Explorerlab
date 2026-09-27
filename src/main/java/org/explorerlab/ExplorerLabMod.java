package org.explorerlab;

import java.util.concurrent.atomic.AtomicLong;

import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** First G0 instrumentation. Tick pausing and private logging are separate gates. */
public final class ExplorerLabMod implements ModInitializer {
    public static final String MOD_ID = "explorerlab";
    private static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);
    private static final AtomicLong OBSERVED_SERVER_TICKS = new AtomicLong();

    @Override
    public void onInitialize() {
        ServerLifecycleEvents.SERVER_STARTED.register(server -> {
            OBSERVED_SERVER_TICKS.set(0);
            LOGGER.info("ExplorerLab G0 loaded; server tick observation started");
        });
        ServerTickEvents.END_SERVER_TICK.register(server -> OBSERVED_SERVER_TICKS.incrementAndGet());
        ServerLifecycleEvents.SERVER_STOPPED.register(server ->
                LOGGER.info("ExplorerLab G0 observed {} server ticks", OBSERVED_SERVER_TICKS.get()));
    }
}
