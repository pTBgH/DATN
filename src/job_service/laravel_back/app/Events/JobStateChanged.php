<?php

namespace App\Events;

use App\Models\Job\JobSubJd;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class JobStateChanged
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public JobSubJd $jobSubJd;

    public function __construct(JobSubJd $jobSubJd)
    {
        $this->jobSubJd = $jobSubJd;
    }
}