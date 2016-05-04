% packet_to_ndarray
% 
% a simple function to convert a packet structarray to an ND array

% Author: Eric E J DeWitt
%
function [nd_array, state, channelmap] = packet_to_ndarray(packet, frequency)
% frequency should be encoded in the data!?
%
%
    if nargin < 2
        frequency = 200;
    end
    safe_f = true;

    % we only parse for identical packets (we could handle packets of different sizes)
    num_channels = packet(1).num_channels;
    num_samples = packet(1).num_samples;
    
    % a way of removing significantly out of time packets (still in sync)
    safe_gap_limit = 1;
    if safe_f
        times = [packet.second];
        unique_times = unique(times);
        last_good_time = unique_times(find(diff(unique_times)>safe_gap_limit));
        if ~isempty(last_good_time)
            bad_packets = times>last_good_time;
            packet = packet(~bad_packets);
            warning(sprintf('%d packets dropped following a gap in data greater than mesh-second %d.', ...
                     sum(bad_packets), last_good_time));
        end
    end
    
    mintime = min([packet.second]);
    maxtime = max([packet.second]);
    ids = unique([packet.id]);
    channelmap = [1:numel(ids); ids]'; % could be struct array
    nsamples = (maxtime - mintime + 1) * frequency;
    nd_array = NaN([nsamples, numel(ids), num_channels]);
    state = NaN([(nsamples / 4), numel(ids), 7]);
    unsync_packets = 0;
    for packet_n = 1:numel(packet)
        % drop out-of-sync packets
        if (~packet(packet_n).sync)
            unsync_packets = unsync_packets + 1;
            continue
        end
        i = channelmap(find(packet(packet_n).id==channelmap(:,2),1));
        t = (packet(packet_n).second - mintime) * frequency + packet(packet_n).counter;
        nd_array(t:t+(num_samples-1),i,:) = packet(packet_n).data;

        state(ceil(t/4),i,:) = [ ...
                      double(packet(packet_n).id), ...
                      double(packet(packet_n).sync), ...
                      double(packet(packet_n).button), ...
                      double(packet(packet_n).aligned), ...
                      double(packet(packet_n).error), ...
                      double(packet(packet_n).second), ...
                      double(packet(packet_n).counter)];
    end
    if (unsync_packets>0)
        warning(sprintf('%d out-of-sync packets dropped.', unsync_packets));
    end
    state(:,:,8) = ((double(state(:,:,6))*frequency)+double(state(:,:,7)))/frequency;
    
end
