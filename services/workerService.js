const { worker } = require('./metadataWorker');

// Compatibility wrapper for telegramService
function enqueueMetadataJob(fileId, filename) {
    // Fire and forget
    worker.processMediaLibrary([{
        fileId,
        filename,
        path: '',
        parentFolder: ''
    }]).catch(err => console.error('[WorkerWrapper] Error:', err.message));
}

// Compatibility wrapper (mostly unused now as worker handles images)
function enqueueImageJob(fileId, url, filepath) {
    // The new worker handles images automatically after metadata fetch.
    // If this is called explicitly (e.g. by legacy code), we can just ignore it 
    // or try to download it using the worker's internal logic if exposed, 
    // but better to just log and skip or use a simple download function if critical.
    // metadataService.js has a downloadImage function for legacy support.
    console.log('[WorkerWrapper] enqueueImageJob is deprecated. Images are handled by MetadataWorker.');
}

function getWorkerStats() {
    return {
        queueLength: 0,
        activeJobs: worker.isRunning ? 1 : 0,
        isProcessing: worker.isRunning
    };
}

module.exports = {
    enqueueMetadataJob,
    enqueueImageJob,
    getWorkerStats
};
